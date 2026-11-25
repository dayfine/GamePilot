type event = Message of Wire.message | Idle | Closed of string

type transport = {
  send : Wire.message -> unit;
  recv : unit -> event;
  wall_ms : unit -> float;
}

exception Protocol_error of string

type t = {
  transport : transport;
  mutable next_id : int;
  mutable next_batch : int;
  mutable latest : Wire.frame option;
  mutable load : int;
  mutable now : float option;
  mutable stop : string option;
  responses : (int, (Wire.json, Wire.error) result) Hashtbl.t;
  dones : (string, Wire.batch_done) Hashtbl.t;
  templates : (Digest.t, Effects.template_hash) Hashtbl.t;
  mutable held : string option;
}

let create transport =
  {
    transport;
    next_id = 1;
    next_batch = 1;
    latest = None;
    load = 0;
    now = None;
    stop = None;
    responses = Hashtbl.create 8;
    dones = Hashtbl.create 8;
    templates = Hashtbl.create 8;
    held = None;
  }

let protocol_error fmt = Printf.ksprintf (fun s -> raise (Protocol_error s)) fmt

(* A frame carries only the results that changed since the previous one
   (contract v1.4; all of them after a subscribe or a load); the others are
   still the held ones. Held probes keep their place, new ones go last. *)
let with_held_results (held : Wire.frame option) (f : Wire.frame) =
  match held with
  | None -> f
  | Some held ->
      let latest (id, r) =
        (id, Option.value (List.assoc_opt id f.probes) ~default:r)
      in
      let is_new (id, _) = not (List.mem_assoc id held.probes) in
      {
        f with
        probes = List.map latest held.probes @ List.filter is_new f.probes;
      }

let take_frame t (frame : Wire.frame) =
  let f = with_held_results t.latest frame in
  t.latest <- Some f;
  t.now <- Some f.t_ms;
  Some f

let take_notification t = function
  | Wire.Frame { load; _ } when load < t.load -> None
  | Wire.Frame { frame; _ } -> take_frame t frame
  | Wire.Batch_done d ->
      Hashtbl.replace t.dones d.batch_id d;
      t.now <- Some d.t_ms;
      None
  | Wire.Stop reason ->
      if t.stop = None then t.stop <- Some reason;
      None
  | Wire.Watch_plan _ | Wire.Watch_log _ | Wire.Watch_run _ ->
      protocol_error "daemon sent a program's watch notification"
  | Wire.Keepawake _ -> protocol_error "daemon sent its own wire log line"

(* A frame taken before the last load shows another state and is dropped. *)
let pump t =
  match t.transport.recv () with
  | Message (Wire.Response { id; outcome }) ->
      Hashtbl.replace t.responses id outcome;
      None
  | Message (Wire.Notification n) -> take_notification t n
  | Message (Wire.Request { call; _ }) ->
      protocol_error "daemon sent a %s request" (Wire.method_name call)
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

let send_request t c =
  let id = t.next_id in
  t.next_id <- id + 1;
  t.transport.send (Wire.Request { id; call = c });
  id

let result_of = function
  | Ok result -> result
  | Error e -> raise (Effects.Rpc_error e)

let call t c = result_of (pump_until t (take t.responses (send_request t c)))

let check_stop t =
  Option.iter (fun reason -> raise (Effects.Stop_requested reason)) t.stop
