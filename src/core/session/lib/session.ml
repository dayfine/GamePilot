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
  mutable load : int;  (** from the last [backend.load_state] reply *)
  mutable now : float option;
  responses : (int, (Wire.json, Wire.error) result) Hashtbl.t;
  dones : (string, Wire.batch_done) Hashtbl.t;
  templates : (Digest.t, Effects.template_hash) Hashtbl.t;
      (** uploaded on this connection, by the MD5 of their PNG bytes *)
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

(* Takes one event from the transport into the session; returns the frame,
   with the held results it did not repeat, if the event was one. A frame
   taken before the last load shows another state and is dropped. *)
let pump t =
  match t.transport.recv () with
  | Message (Wire.Response { id; outcome }) ->
      Hashtbl.replace t.responses id outcome;
      None
  | Message (Wire.Notification (Wire.Frame { load; _ })) when load < t.load ->
      None
  | Message (Wire.Notification (Wire.Frame { frame; _ })) ->
      let f = with_held_results t.latest frame in
      t.latest <- Some f;
      t.now <- Some f.t_ms;
      Some f
  | Message (Wire.Notification (Wire.Batch_done d)) ->
      Hashtbl.replace t.dones d.batch_id d;
      t.now <- Some d.t_ms;
      None
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

let hello t =
  let r =
    Wire.hello_result_of_json
      (call t
         (Wire.Hello { protocol = protocol_version; client = client_name }))
  in
  if r.protocol <> protocol_version then
    protocol_error "daemon speaks protocol %d, we speak %d" r.protocol
      protocol_version

let next_batch_id t =
  let batch_id = Printf.sprintf "b%d" t.next_batch in
  t.next_batch <- t.next_batch + 1;
  batch_id

let check_submitted batch_id result =
  let r = Wire.submit_result_of_json result in
  if r.batch_id <> batch_id then
    protocol_error "submit %s answered for batch %s" batch_id r.batch_id

let submit t commands =
  let batch_id = next_batch_id t in
  check_submitted batch_id (call t (Wire.Submit { batch_id; commands }));
  pump_until t (take t.dones batch_id)

(* Cancels the batch [race] stopped. Its [batch_done] can still arrive before
   the cancel's reply (it was on its way); after the reply none can, so the one
   that came is dropped there. *)
let cancel_batch t batch_id =
  ignore (Wire.cancel_result_of_json (call t Wire.Cancel) : int);
  Hashtbl.remove t.dones batch_id

(* Every frame pumped after the submit was sent is checked against [stop],
   also while its reply is still on the way. *)
let race t commands stop =
  let batch_id = next_batch_id t in
  let id = send_request t (Wire.Submit { batch_id; commands }) in
  let check_reply () =
    Option.iter
      (fun r -> check_submitted batch_id (result_of r))
      (take t.responses id ())
  in
  let rec watch () =
    check_reply ();
    match take t.dones batch_id () with
    | Some d -> Effects.Finished d
    | None -> (
        match pump t with
        | Some f when stop f -> Effects.Stopped f
        | Some _ | None -> watch ())
  in
  let raced = watch () in
  match raced with
  | Effects.Finished _ -> raced
  | Effects.Stopped _ ->
      cancel_batch t batch_id;
      (* The submit's reply, if it was still on the way, came before the
         cancel's. *)
      check_reply ();
      raced

(* The daemon keeps uploads until the connection closes, so each PNG goes up
   once. *)
let upload_template t png =
  let key = Digest.string png in
  match Hashtbl.find_opt t.templates key with
  | Some hash -> hash
  | None ->
      let hash =
        Wire.upload_template_result_of_json
          (call t (Wire.Upload_template { png }))
      in
      Hashtbl.replace t.templates key hash;
      hash

(* One [await] call. [deadline] is in daemon time; without any frame yet, the
   clock starts at the first one. [wall_deadline] catches stalled frames. *)
type wait = {
  pred : Wire.frame -> bool;
  timeout : float;
  wall_deadline : float;
  mutable deadline : float option;
}

let frame_deadline w (f : Wire.frame) =
  match w.deadline with
  | Some d -> d
  | None ->
      let d = f.t_ms +. w.timeout in
      w.deadline <- Some d;
      d

(* What the pumped event decides for the wait, if anything. *)
let wait_verdict t w = function
  | Some (f : Wire.frame) ->
      if f.t_ms > frame_deadline w f then Some Effects.Timeout
      else if w.pred f then Some (Effects.Holds f)
      else None
  | None ->
      if t.transport.wall_ms () > w.wall_deadline then Some Effects.Timeout
      else None

let rec wait_for_frames t w =
  match wait_verdict t w (pump t) with
  | Some awaited -> awaited
  | None -> wait_for_frames t w

let await t pred timeout_ms =
  let timeout = float_of_int timeout_ms in
  let w =
    {
      pred;
      timeout;
      wall_deadline = t.transport.wall_ms () +. timeout +. stall_slack_ms;
      deadline = Option.map (fun now -> now +. timeout) t.now;
    }
  in
  match t.latest with
  | Some f when pred f -> Effects.Holds f
  | _ -> wait_for_frames t w

let load_state t path =
  let r = Wire.load_state_result_of_json (call t (Wire.Load_state { path })) in
  t.load <- r.load;
  t.latest <- None;
  r.seq

(* The first frame after a subscribe carries every subscribed result. *)
let first_results_timeout_ms = 1000

let has_results ids (f : Wire.frame) =
  List.for_all (fun id -> List.mem_assoc id f.probes) ids

let subscribe t probes =
  let ids = Wire.subscribe_result_of_json (call t (Wire.Subscribe probes)) in
  ignore (await t (has_results ids) first_results_timeout_ms : Effects.awaited);
  ids

(* The latest frame keeps no result of a probe that is gone, so a later
   subscribe of the same id waits for a fresh one. *)
let unsubscribe t ids =
  let removed =
    Wire.unsubscribe_result_of_json (call t (Wire.Unsubscribe ids))
  in
  t.latest <-
    Option.map
      (fun (f : Wire.frame) ->
        {
          f with
          probes = List.filter (fun (id, _) -> not (List.mem id ids)) f.probes;
        })
      t.latest;
  removed

(* The session's answer to an effect, or [None] for effects it does not
   handle. *)
let answer : type a. t -> a Effect.t -> (unit -> a) option =
 fun t eff ->
  match eff with
  | Effects.Submit commands -> Some (fun () -> submit t commands)
  | Effects.Race (commands, stop) -> Some (fun () -> race t commands stop)
  | Effects.Await (pred, timeout_ms) -> Some (fun () -> await t pred timeout_ms)
  | Effects.Now -> Some (fun () -> Option.value t.now ~default:0.)
  | Effects.Read -> Some (fun () -> t.latest)
  | Effects.Load_state path -> Some (fun () -> load_state t path)
  | Effects.Upload_template png -> Some (fun () -> upload_template t png)
  | Effects.Subscribe probes -> Some (fun () -> subscribe t probes)
  | Effects.Unsubscribe ids -> Some (fun () -> unsubscribe t ids)
  | _ -> None

(* Errors go back into the program, so its own handlers see them. *)
let resume k answer =
  match answer () with
  | x -> Effect.Deep.continue k x
  | exception e -> Effect.Deep.discontinue k e

let handle t f =
  Effect.Deep.try_with f ()
    {
      effc =
        (fun eff -> Option.map (fun answer k -> resume k answer) (answer t eff));
    }

let run transport f =
  let t =
    {
      transport;
      next_id = 1;
      next_batch = 1;
      latest = None;
      load = 0;
      now = None;
      responses = Hashtbl.create 8;
      dones = Hashtbl.create 8;
      templates = Hashtbl.create 8;
    }
  in
  hello t;
  handle t f
