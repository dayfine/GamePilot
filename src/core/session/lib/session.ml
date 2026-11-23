type event = Message of Wire.message | Idle | Closed of string

type transport = {
  send : Wire.message -> unit;
  recv : unit -> event;
  wall_ms : unit -> float;
}

exception Protocol_error of string

let stall_slack_ms = 1000.
let client_name = "gamepilot-programs/0.1"
let protocol_version = 1

type t = {
  transport : transport;
  mutable next_id : int;
  mutable next_batch : int;
  mutable latest : Wire.frame option;
  mutable now : float option;
  responses : (int, (Wire.json, Wire.error) result) Hashtbl.t;
  dones : (string, Wire.batch_done) Hashtbl.t;
}

(* Takes one event from the transport into the session; returns the frame if
   the event was one. *)
let pump t =
  match t.transport.recv () with
  | Message (Wire.Response { id; outcome }) ->
      Hashtbl.replace t.responses id outcome;
      None
  | Message (Wire.Notification (Wire.Frame f)) ->
      t.latest <- Some f;
      t.now <- Some f.t_ms;
      Some f
  | Message (Wire.Notification (Wire.Batch_done d)) ->
      Hashtbl.replace t.dones d.batch_id d;
      t.now <- Some d.t_ms;
      None
  | Message (Wire.Request { call; _ }) ->
      raise
        (Protocol_error
           (Printf.sprintf "daemon sent a %s request" (Wire.method_name call)))
  | Idle -> None
  | Closed why -> raise (Effects.Disconnected why)

let rec pump_until t ready =
  match ready () with
  | Some v -> v
  | None ->
      ignore (pump t);
      pump_until t ready

let take tbl key () =
  match Hashtbl.find_opt tbl key with
  | Some v ->
      Hashtbl.remove tbl key;
      Some v
  | None -> None

let call t c =
  let id = t.next_id in
  t.next_id <- id + 1;
  t.transport.send (Wire.Request { id; call = c });
  match pump_until t (take t.responses id) with
  | Ok result -> result
  | Error e -> raise (Effects.Rpc_error e)

let hello t =
  let r =
    Wire.hello_result_of_json
      (call t
         (Wire.Hello { protocol = protocol_version; client = client_name }))
  in
  if r.protocol <> protocol_version then
    raise
      (Protocol_error
         (Printf.sprintf "daemon speaks protocol %d, we speak %d" r.protocol
            protocol_version))

let submit t commands =
  let batch_id = Printf.sprintf "b%d" t.next_batch in
  t.next_batch <- t.next_batch + 1;
  let r =
    Wire.submit_result_of_json (call t (Wire.Submit { batch_id; commands }))
  in
  if r.batch_id <> batch_id then
    raise
      (Protocol_error
         (Printf.sprintf "submit %s answered for batch %s" batch_id r.batch_id));
  pump_until t (take t.dones batch_id)

let await t pred timeout_ms =
  let timeout = float_of_int timeout_ms in
  let wall_deadline = t.transport.wall_ms () +. timeout +. stall_slack_ms in
  (* Without any frame yet, the clock starts at the first one. *)
  let deadline = ref (Option.map (fun now -> now +. timeout) t.now) in
  let rec loop () =
    match pump t with
    | Some (f : Wire.frame) ->
        let d =
          match !deadline with
          | Some d -> d
          | None ->
              let d = f.t_ms +. timeout in
              deadline := Some d;
              d
        in
        if f.t_ms > d then Effects.Timeout
        else if pred f then Effects.Holds f
        else loop ()
    | None ->
        if t.transport.wall_ms () > wall_deadline then Effects.Timeout
        else loop ()
  in
  match t.latest with Some f when pred f -> Effects.Holds f | _ -> loop ()

let handle t f =
  let open Effect.Deep in
  try_with f ()
    {
      effc =
        (fun (type a) (eff : a Effect.t) ->
          (* Errors go back into the program, so its own handlers see them. *)
          let answer (v : unit -> a) =
            Some
              (fun (k : (a, _) continuation) ->
                match v () with
                | x -> continue k x
                | exception e -> discontinue k e)
          in
          match eff with
          | Effects.Submit commands -> answer (fun () -> submit t commands)
          | Effects.Await (pred, timeout_ms) ->
              answer (fun () -> await t pred timeout_ms)
          | Effects.Now -> answer (fun () -> Option.value t.now ~default:0.)
          | Effects.Read -> answer (fun () -> t.latest)
          | Effects.Load_state path ->
              answer (fun () ->
                  let seq =
                    Wire.load_state_result_of_json
                      (call t (Wire.Load_state { path }))
                  in
                  (* Frames from before the load describe another state. *)
                  t.latest <- None;
                  seq)
          | Effects.Subscribe probes ->
              answer (fun () ->
                  Wire.subscribe_result_of_json (call t (Wire.Subscribe probes)))
          | _ -> None);
    }

let run transport f =
  let t =
    {
      transport;
      next_id = 1;
      next_batch = 1;
      latest = None;
      now = None;
      responses = Hashtbl.create 8;
      dones = Hashtbl.create 8;
    }
  in
  hello t;
  handle t f
