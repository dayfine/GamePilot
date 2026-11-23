type json = Yojson.Safe.t

exception Decode_error of string

let fail fmt = Printf.ksprintf (fun s -> raise (Decode_error s)) fmt

(* Field access helpers. *)

let fields what = function
  | `Assoc kv -> kv
  | _ -> fail "%s: expected an object" what

let field what name j =
  match List.assoc_opt name (fields what j) with
  | Some v -> v
  | None -> fail "%s: missing field %S" what name

let field_opt what name j = List.assoc_opt name (fields what j)

let to_int what = function
  | `Int i -> i
  | `Float f when Float.is_integer f -> int_of_float f
  | _ -> fail "%s: expected an integer" what

let to_float what = function
  | `Int i -> float_of_int i
  | `Float f -> f
  | _ -> fail "%s: expected a number" what

let to_string what = function
  | `String s -> s
  | _ -> fail "%s: expected a string" what

let to_list what = function
  | `List l -> l
  | _ -> fail "%s: expected a list" what

let int_field what name j = to_int (what ^ "." ^ name) (field what name j)
let float_field what name j = to_float (what ^ "." ^ name) (field what name j)
let string_field what name j = to_string (what ^ "." ^ name) (field what name j)
let list_field what name j = to_list (what ^ "." ^ name) (field what name j)

(* Values *)

type button = A | B | Select | Start | Right | Left | Up | Down | R | L

let all_buttons = [ A; B; Select; Start; Right; Left; Up; Down; R; L ]

let string_of_button = function
  | A -> "A"
  | B -> "B"
  | Select -> "Select"
  | Start -> "Start"
  | Right -> "Right"
  | Left -> "Left"
  | Up -> "Up"
  | Down -> "Down"
  | R -> "R"
  | L -> "L"

let button_of_string s =
  List.find_opt (fun b -> string_of_button b = s) all_buttons

type command =
  | Press of { buttons : button list; hold_ms : int; cooldown_ms : int }
  | Wait of { wait_ms : int }

let command_of_json j =
  let what = "command" in
  match field_opt what "press" j with
  | Some press ->
      let button v =
        let s = to_string "command.press" v in
        match button_of_string s with
        | Some b -> b
        | None -> fail "command.press: unknown button %S" s
      in
      Press
        {
          buttons = List.map button (to_list "command.press" press);
          hold_ms = int_field what "hold_ms" j;
          cooldown_ms = int_field what "cooldown_ms" j;
        }
  | None -> Wait { wait_ms = int_field what "wait_ms" j }

let json_of_command = function
  | Press { buttons; hold_ms; cooldown_ms } ->
      `Assoc
        [
          ( "press",
            `List (List.map (fun b -> `String (string_of_button b)) buttons) );
          ("hold_ms", `Int hold_ms);
          ("cooldown_ms", `Int cooldown_ms);
        ]
  | Wait { wait_ms } -> `Assoc [ ("wait_ms", `Int wait_ms) ]

type box = { x : float; y : float; w : float; h : float }

let box_of_json j =
  let f = float_field "box" in
  { x = f "x" j; y = f "y" j; w = f "w" j; h = f "h" j }

let json_of_box { x; y; w; h } =
  `Assoc [ ("x", `Float x); ("y", `Float y); ("w", `Float w); ("h", `Float h) ]

type delivery = Every | Latest

type probe_spec = {
  id : string;
  kind : string;
  box : box;
  delivery : delivery;
  template : string option;
}

let color_stats_kind = "core.color_stats@1"
let template_match_kind = "core.template_match@1"

let color_stats_probe ~id ~box ~delivery =
  { id; kind = color_stats_kind; box; delivery; template = None }

let template_match_probe ~id ~box ~delivery ~template =
  { id; kind = template_match_kind; box; delivery; template = Some template }

let probe_spec_of_json j =
  let what = "probe" in
  {
    id = string_field what "id" j;
    kind = string_field what "kind" j;
    box = box_of_json (field what "box" j);
    delivery =
      (match string_field what "delivery" j with
      | "every" -> Every
      | "latest" -> Latest
      | s -> fail "probe.delivery: unknown value %S" s);
    template =
      Option.map (to_string "probe.template") (field_opt what "template" j);
  }

let json_of_probe_spec { id; kind; box; delivery; template } =
  `Assoc
    ([
       ("id", `String id);
       ("kind", `String kind);
       ("box", json_of_box box);
       ( "delivery",
         `String (match delivery with Every -> "every" | Latest -> "latest") );
     ]
    @ match template with Some t -> [ ("template", `String t) ] | None -> [])

type rgb = { r : float; g : float; b : float }

let rgb_of_json what j =
  match to_list what j with
  | [ r; g; b ] ->
      { r = to_float what r; g = to_float what g; b = to_float what b }
  | _ -> fail "%s: expected [r, g, b]" what

let json_of_rgb { r; g; b } = `List [ `Float r; `Float g; `Float b ]

type probe_result =
  | Color_stats of { mean : rgb; stddev : rgb }
  | Template_match of { score : float; x : float; y : float }
  | Other of json

let probe_result_of_json j =
  let what = "probe result" in
  match string_field what "kind" j with
  | kind when kind = color_stats_kind ->
      Color_stats
        {
          mean = rgb_of_json "probe.mean" (field what "mean" j);
          stddev = rgb_of_json "probe.stddev" (field what "stddev" j);
        }
  | kind when kind = template_match_kind ->
      let f = float_field what in
      Template_match { score = f "score" j; x = f "x" j; y = f "y" j }
  | _ -> Other j

let json_of_probe_result = function
  | Color_stats { mean; stddev } ->
      `Assoc
        [
          ("kind", `String color_stats_kind);
          ("mean", json_of_rgb mean);
          ("stddev", json_of_rgb stddev);
        ]
  | Template_match { score; x; y } ->
      `Assoc
        [
          ("kind", `String template_match_kind);
          ("score", `Float score);
          ("x", `Float x);
          ("y", `Float y);
        ]
  | Other j -> j

type frame = { seq : int; t_ms : float; probes : (string * probe_result) list }

let frame_of_json j =
  let what = "frame" in
  {
    seq = int_field what "seq" j;
    t_ms = float_field what "t_ms" j;
    probes =
      List.map
        (fun (id, v) -> (id, probe_result_of_json v))
        (fields "frame.probes" (field what "probes" j));
  }

let json_of_frame ~load { seq; t_ms; probes } =
  `Assoc
    [
      ("seq", `Int seq);
      ("load", `Int load);
      ("t_ms", `Float t_ms);
      ( "probes",
        `Assoc (List.map (fun (id, r) -> (id, json_of_probe_result r)) probes)
      );
    ]

type batch_done = { batch_id : string; seq : int; t_ms : float }

let batch_done_of_json j : batch_done =
  let what = "batch_done" in
  {
    batch_id = string_field what "batch_id" j;
    seq = int_field what "seq" j;
    t_ms = float_field what "t_ms" j;
  }

let json_of_batch_done ({ batch_id; seq; t_ms } : batch_done) =
  `Assoc
    [ ("batch_id", `String batch_id); ("seq", `Int seq); ("t_ms", `Float t_ms) ]

type backend = {
  kind : string;
  game_code : string;
  frame_rate : float;
  width : int;
  height : int;
}

type hello_result = {
  protocol : int;
  daemon : string;
  backend : backend;
  probe_kinds : string list;
}

type submit_result = { batch_id : string; start_seq : int }
type error = { code : int; message : string; data : json option }

let error_of_json j =
  let what = "error" in
  {
    code = int_field what "code" j;
    message = string_field what "message" j;
    data = field_opt what "data" j;
  }

let json_of_error { code; message; data } =
  `Assoc
    ([ ("code", `Int code); ("message", `String message) ]
    @ match data with Some d -> [ ("data", d) ] | None -> [])

(* Messages *)

type call =
  | Hello of { protocol : int; client : string }
  | Load_state of { path : string }
  | Upload_template of { png : string }
  | Subscribe of probe_spec list
  | Submit of { batch_id : string; commands : command list }
  | Cancel

type request = { id : int; call : call }
type response = { id : int; outcome : (json, error) result }

type notification =
  | Frame of { load : int; frame : frame }
  | Batch_done of batch_done

type message =
  | Request of request
  | Response of response
  | Notification of notification

let method_name = function
  | Hello _ -> "hello"
  | Load_state _ -> "backend.load_state"
  | Upload_template _ -> "probe.upload_template"
  | Subscribe _ -> "subscribe"
  | Submit _ -> "submit"
  | Cancel -> "cancel"

let call_of_json name params =
  let what = name ^ ".params" in
  match name with
  | "hello" ->
      Hello
        {
          protocol = int_field what "protocol" params;
          client = string_field what "client" params;
        }
  | "backend.load_state" ->
      Load_state { path = string_field what "path" params }
  | "probe.upload_template" -> (
      match Base64.decode (string_field what "png" params) with
      | Some png -> Upload_template { png }
      | None -> fail "%s.png: expected padded base64" what)
  | "subscribe" ->
      Subscribe (List.map probe_spec_of_json (list_field what "probes" params))
  | "submit" ->
      Submit
        {
          batch_id = string_field what "batch_id" params;
          commands =
            List.map command_of_json (list_field what "commands" params);
        }
  | "cancel" -> Cancel
  | m -> fail "unknown method %S" m

let params_of_call = function
  | Hello { protocol; client } ->
      `Assoc [ ("protocol", `Int protocol); ("client", `String client) ]
  | Load_state { path } -> `Assoc [ ("path", `String path) ]
  | Upload_template { png } -> `Assoc [ ("png", `String (Base64.encode png)) ]
  | Subscribe probes ->
      `Assoc [ ("probes", `List (List.map json_of_probe_spec probes)) ]
  | Submit { batch_id; commands } ->
      `Assoc
        [
          ("batch_id", `String batch_id);
          ("commands", `List (List.map json_of_command commands));
        ]
  | Cancel -> `Assoc []

let message_of_json j =
  let what = "message" in
  (match field_opt what "jsonrpc" j with
  | Some (`String "2.0") -> ()
  | _ -> fail "message: jsonrpc must be \"2.0\"");
  let params () =
    match field_opt what "params" j with Some p -> p | None -> `Assoc []
  in
  match (field_opt what "id" j, field_opt what "method" j) with
  | Some id, Some m ->
      let name = to_string "message.method" m in
      Request
        { id = to_int "message.id" id; call = call_of_json name (params ()) }
  | Some id, None ->
      let id = to_int "message.id" id in
      let outcome =
        match (field_opt what "result" j, field_opt what "error" j) with
        | Some r, None -> Ok r
        | None, Some e -> Error (error_of_json e)
        | _ -> fail "response %d: needs exactly one of result and error" id
      in
      Response { id; outcome }
  | None, Some (`String "frame") ->
      let p = params () in
      Notification
        (Frame { load = int_field "frame" "load" p; frame = frame_of_json p })
  | None, Some (`String "batch_done") ->
      Notification (Batch_done (batch_done_of_json (params ())))
  | None, Some m -> fail "unknown notification %s" (Yojson.Safe.to_string m)
  | None, None ->
      fail "message: neither a request, a response nor a notification"

let envelope rest = `Assoc (("jsonrpc", `String "2.0") :: rest)

let json_of_message = function
  | Request { id; call } ->
      envelope
        [
          ("id", `Int id);
          ("method", `String (method_name call));
          ("params", params_of_call call);
        ]
  | Response { id; outcome = Ok r } ->
      envelope [ ("id", `Int id); ("result", r) ]
  | Response { id; outcome = Error e } ->
      envelope [ ("id", `Int id); ("error", json_of_error e) ]
  | Notification (Frame { load; frame }) ->
      envelope
        [ ("method", `String "frame"); ("params", json_of_frame ~load frame) ]
  | Notification (Batch_done d) ->
      envelope
        [ ("method", `String "batch_done"); ("params", json_of_batch_done d) ]

let parse_json s =
  try Yojson.Safe.from_string s
  with Yojson.Json_error e -> fail "bad JSON: %s" e

let message_of_string s = message_of_json (parse_json s)
let string_of_message m = Yojson.Safe.to_string (json_of_message m)

(* Results *)

let hello_result_of_json j =
  let what = "hello.result" in
  let b = field what "backend" j in
  let bw = "hello.result.backend" in
  {
    protocol = int_field what "protocol" j;
    daemon = string_field what "daemon" j;
    backend =
      {
        kind = string_field bw "kind" b;
        game_code = string_field bw "game_code" b;
        frame_rate = float_field bw "frame_rate" b;
        width = int_field bw "width" b;
        height = int_field bw "height" b;
      };
    probe_kinds =
      List.map (to_string "probe_kinds") (list_field what "probe_kinds" j);
  }

let json_of_hello_result { protocol; daemon; backend; probe_kinds } =
  `Assoc
    [
      ("protocol", `Int protocol);
      ("daemon", `String daemon);
      ( "backend",
        `Assoc
          [
            ("kind", `String backend.kind);
            ("game_code", `String backend.game_code);
            ("frame_rate", `Float backend.frame_rate);
            ("width", `Int backend.width);
            ("height", `Int backend.height);
          ] );
      ("probe_kinds", `List (List.map (fun k -> `String k) probe_kinds));
    ]

type load_state_result = { seq : int; load : int }

let load_state_result_of_json j =
  let what = "backend.load_state.result" in
  { seq = int_field what "seq" j; load = int_field what "load" j }

let json_of_load_state_result { seq; load } =
  `Assoc [ ("seq", `Int seq); ("load", `Int load) ]

let upload_template_result_of_json j =
  string_field "probe.upload_template.result" "template" j

let json_of_upload_template_result hash = `Assoc [ ("template", `String hash) ]

let subscribe_result_of_json j =
  List.map
    (to_string "subscribe.result.subscribed")
    (list_field "subscribe.result" "subscribed" j)

let json_of_subscribe_result ids =
  `Assoc [ ("subscribed", `List (List.map (fun i -> `String i) ids)) ]

let submit_result_of_json j =
  let what = "submit.result" in
  {
    batch_id = string_field what "batch_id" j;
    start_seq = int_field what "start_seq" j;
  }

let json_of_submit_result ({ batch_id; start_seq } : submit_result) =
  `Assoc [ ("batch_id", `String batch_id); ("start_seq", `Int start_seq) ]

let cancel_result_of_json j = int_field "cancel.result" "released_seq" j
let json_of_cancel_result seq = `Assoc [ ("released_seq", `Int seq) ]

(* Wire log *)

type direction = In | Out
type log_line = { dir : direction; t_ms : float; msg : message }

let log_line_of_json j =
  let what = "wire log line" in
  {
    dir =
      (match string_field what "dir" j with
      | "in" -> In
      | "out" -> Out
      | s -> fail "wire log line: dir %S is neither in nor out" s);
    t_ms = float_field what "t_ms" j;
    msg = message_of_json (field what "msg" j);
  }

let json_of_log_line { dir; t_ms; msg } =
  `Assoc
    [
      ("dir", `String (match dir with In -> "in" | Out -> "out"));
      ("t_ms", `Float t_ms);
      ("msg", json_of_message msg);
    ]
