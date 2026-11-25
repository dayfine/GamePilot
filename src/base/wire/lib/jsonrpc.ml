open Json_fields

type json = Yojson.Safe.t
type error = { code : int; message : string; data : json option }

let error_of_json j =
  let what = "error" in
  {
    code = int_field what "code" j;
    message = string_field what "message" j;
    data = field_opt what "data" j;
  }

let json_of_data = function Some d -> [ ("data", d) ] | None -> []

let json_of_error { code; message; data } =
  `Assoc
    ([ ("code", `Int code); ("message", `String message) ] @ json_of_data data)

type call =
  | Hello of { protocol : int; client : string }
  | Load_state of { path : string }
  | Save_state of { path : string }
  | Save_frame of { path : string }
  | Upload_template of { png : string }
  | Subscribe of Probe.probe_spec list
  | Unsubscribe of string list
  | Submit of { batch_id : string; commands : Command.command list }
  | Cancel
  | Cancel_then of { batch_id : string; commands : Command.command list }
  | Status
  | Lease_acquire of { owner : string; ttl_ms : int option }
  | Lease_release

type request = { id : int; call : call }
type response = { id : int; outcome : (json, error) result }

type notification =
  | Frame of { load : int; frame : Probe.frame }
  | Batch_done of Command.batch_done
  | Watch_plan of Watch.plan
  | Watch_log of string
  | Watch_run of Watch_run.t
  | Stop of string
  | Keepawake of { key : string; idle_ms : int }

type message =
  | Request of request
  | Response of response
  | Notification of notification

let method_name = function
  | Hello _ -> "hello"
  | Load_state _ -> "backend.load_state"
  | Save_state _ -> "backend.save_state"
  | Save_frame _ -> "backend.save_frame"
  | Upload_template _ -> "probe.upload_template"
  | Subscribe _ -> "subscribe"
  | Unsubscribe _ -> "unsubscribe"
  | Submit _ -> "submit"
  | Cancel | Cancel_then _ -> "cancel"
  | Status -> "status"
  | Lease_acquire _ -> "lease.acquire"
  | Lease_release -> "lease.release"

let hello_of_params what params =
  Hello
    {
      protocol = int_field what "protocol" params;
      client = string_field what "client" params;
    }

let upload_template_of_params what params =
  match Base64.decode (string_field what "png" params) with
  | Some png -> Upload_template { png }
  | None -> fail "%s.png: expected padded base64" what

let lease_acquire_of_params what params =
  let ttl_ms = field_opt what "ttl_ms" params in
  Lease_acquire
    {
      owner = string_field what "owner" params;
      ttl_ms = Option.map (to_int (what ^ ".ttl_ms")) ttl_ms;
    }

let submit_of_params what params =
  Submit
    {
      batch_id = string_field what "batch_id" params;
      commands =
        List.map Command.command_of_json (list_field what "commands" params);
    }

let cancel_of_params what params =
  match field_opt what "then" params with
  | None -> Cancel
  | Some then_ -> (
      match submit_of_params (what ^ ".then") then_ with
      | Submit { batch_id; commands } -> Cancel_then { batch_id; commands }
      | _ -> fail "%s.then: not a batch" what)

let call_of_json name params =
  let what = name ^ ".params" in
  match name with
  | "hello" -> hello_of_params what params
  | "backend.load_state" ->
      Load_state { path = string_field what "path" params }
  | "backend.save_state" ->
      Save_state { path = string_field what "path" params }
  | "backend.save_frame" ->
      Save_frame { path = string_field what "path" params }
  | "probe.upload_template" -> upload_template_of_params what params
  | "subscribe" ->
      Subscribe
        (List.map Probe.probe_spec_of_json (list_field what "probes" params))
  | "unsubscribe" -> Unsubscribe (string_list_field what "ids" params)
  | "submit" -> submit_of_params what params
  | "cancel" -> cancel_of_params what params
  | "status" -> Status
  | "lease.acquire" -> lease_acquire_of_params what params
  | "lease.release" -> Lease_release
  | m -> fail "unknown method %S" m

let submit_params batch_id commands =
  `Assoc
    [
      ("batch_id", `String batch_id);
      ("commands", `List (List.map Command.json_of_command commands));
    ]

let params_of_call = function
  | Hello { protocol; client } ->
      `Assoc [ ("protocol", `Int protocol); ("client", `String client) ]
  | Load_state { path } | Save_state { path } | Save_frame { path } ->
      `Assoc [ ("path", `String path) ]
  | Upload_template { png } -> `Assoc [ ("png", `String (Base64.encode png)) ]
  | Subscribe probes ->
      `Assoc [ ("probes", `List (List.map Probe.json_of_probe_spec probes)) ]
  | Unsubscribe ids -> `Assoc [ ("ids", json_of_strings ids) ]
  | Submit { batch_id; commands } -> submit_params batch_id commands
  | Cancel_then { batch_id; commands } ->
      `Assoc [ ("then", submit_params batch_id commands) ]
  | Lease_acquire { owner; ttl_ms } ->
      `Assoc
        (("owner", `String owner)
        :: Option.fold ~none:[] ~some:(fun ms -> [ ("ttl_ms", `Int ms) ]) ttl_ms
        )
  | Cancel | Status | Lease_release -> `Assoc []

let check_version j =
  match field_opt "message" "jsonrpc" j with
  | Some (`String "2.0") -> ()
  | _ -> fail "message: jsonrpc must be \"2.0\""

let params j =
  match field_opt "message" "params" j with Some p -> p | None -> `Assoc []

let request_of_json id m j =
  let name = to_string "message.method" m in
  Request { id = to_int "message.id" id; call = call_of_json name (params j) }

let response_of_json id j =
  let id = to_int "message.id" id in
  let outcome =
    match (field_opt "message" "result" j, field_opt "message" "error" j) with
    | Some r, None -> Ok r
    | None, Some e -> Error (error_of_json e)
    | _ -> fail "response %d: needs exactly one of result and error" id
  in
  Response { id; outcome }

let frame_notification_of_json j =
  let p = params j in
  Frame { load = int_field "frame" "load" p; frame = Probe.frame_of_json p }

let keepawake_of_json p =
  Keepawake
    {
      key = string_field "keepawake" "key" p;
      idle_ms = int_field "keepawake" "idle_ms" p;
    }

let notification_of_json m j =
  match m with
  | `String "frame" -> Notification (frame_notification_of_json j)
  | `String "batch_done" ->
      Notification (Batch_done (Command.batch_done_of_json (params j)))
  | `String "watch.plan" ->
      Notification (Watch_plan (Watch.plan_of_json (params j)))
  | `String "watch.log" ->
      Notification (Watch_log (Watch.line_of_json (params j)))
  | `String "watch.run" ->
      Notification (Watch_run (Watch_run.of_json (params j)))
  | `String "stop" -> Notification (Stop (Watch.reason_of_json (params j)))
  | `String "keepawake" -> Notification (keepawake_of_json (params j))
  | m -> fail "unknown notification %s" (Yojson.Safe.to_string m)

let message_of_json j =
  check_version j;
  match (field_opt "message" "id" j, field_opt "message" "method" j) with
  | Some id, Some m -> request_of_json id m j
  | Some id, None -> response_of_json id j
  | None, Some m -> notification_of_json m j
  | None, None ->
      fail "message: neither a request, a response nor a notification"

let envelope rest = `Assoc (("jsonrpc", `String "2.0") :: rest)

let json_of_notification = function
  | Frame { load; frame } ->
      [
        ("method", `String "frame"); ("params", Probe.json_of_frame ~load frame);
      ]
  | Batch_done d ->
      [
        ("method", `String "batch_done");
        ("params", Command.json_of_batch_done d);
      ]
  | Watch_plan plan ->
      [ ("method", `String "watch.plan"); ("params", Watch.json_of_plan plan) ]
  | Watch_log line ->
      [ ("method", `String "watch.log"); ("params", Watch.json_of_line line) ]
  | Watch_run run ->
      [ ("method", `String "watch.run"); ("params", Watch_run.to_json run) ]
  | Stop reason ->
      [ ("method", `String "stop"); ("params", Watch.json_of_reason reason) ]
  | Keepawake { key; idle_ms } ->
      [
        ("method", `String "keepawake");
        ("params", `Assoc [ ("key", `String key); ("idle_ms", `Int idle_ms) ]);
      ]

let json_of_request { id; call } =
  [
    ("id", `Int id);
    ("method", `String (method_name call));
    ("params", params_of_call call);
  ]

let json_of_message = function
  | Request r -> envelope (json_of_request r)
  | Response { id; outcome = Ok r } ->
      envelope [ ("id", `Int id); ("result", r) ]
  | Response { id; outcome = Error e } ->
      envelope [ ("id", `Int id); ("error", json_of_error e) ]
  | Notification n -> envelope (json_of_notification n)

let message_of_string s = message_of_json (parse_json s)
let string_of_message m = Yojson.Safe.to_string (json_of_message m)
