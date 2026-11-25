include Client_connection

let stall_slack_ms = 1000.
let client_name = "gamepilot-programs/0.1"
let protocol_version = 1

let hello ~client t =
  let r =
    Wire.hello_result_of_json
      (call t (Wire.Hello { protocol = protocol_version; client }))
  in
  if r.protocol <> protocol_version then
    protocol_error "daemon speaks protocol %d, we speak %d" r.protocol
      protocol_version;
  r.backend

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
  check_stop t;
  check_submitted batch_id (call t (Wire.Submit { batch_id; commands }));
  pump_until t (fun () ->
      check_stop t;
      take t.dones batch_id ())

(* Returns once the daemon accepted the batch; its end is not waited for. *)
let queue t commands =
  let batch_id = next_batch_id t in
  check_stop t;
  Hashtbl.replace t.queued batch_id ();
  check_submitted batch_id (call t (Wire.Submit { batch_id; commands }))

(* Cancels the batch [race] stopped. Its [batch_done] can still arrive before
   the cancel's reply (it was on its way); after the reply none can, so the one
   that came is dropped there. *)
let cancel_batch t batch_id =
  ignore (Wire.cancel_result_of_json (call t Wire.Cancel) : int);
  Hashtbl.remove t.dones batch_id

(* Every frame pumped after the submit was sent is checked against [stop],
   also while its reply is still on the way. On a stop, [after] ends the
   batch: a cancel, or a cancel into the next batch. *)
let race_ending t commands stop after =
  check_stop t;
  let batch_id = next_batch_id t in
  let id = send_request t (Wire.Submit { batch_id; commands }) in
  let check_reply () =
    Option.iter
      (fun r -> check_submitted batch_id (result_of r))
      (take t.responses id ())
  in
  let rec watch () =
    check_stop t;
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
  | Effects.Stopped f ->
      after batch_id f;
      (* The submit's reply, if it was still on the way, came before the
         cancel's. *)
      check_reply ();
      raced

let race t commands stop =
  race_ending t commands stop (fun batch_id _ -> cancel_batch t batch_id)

(* Cancels the held batch into [commands]; that batch's [batch_done] ends the
   op. With none held, the commands are a plain submit. *)
let replace t commands =
  match t.held with
  | None -> submit t commands
  | Some held ->
      t.held <- None;
      let next = next_batch_id t in
      let cancel = Wire.Cancel_then { batch_id = next; commands } in
      ignore (Wire.cancel_result_of_json (call t cancel) : int);
      Hashtbl.remove t.dones held;
      pump_until t (fun () ->
          check_stop t;
          take t.dones next ())

(* The stopped batch runs on until [replace]. *)
let race_held t commands stop =
  race_ending t commands stop (fun batch_id _ -> t.held <- Some batch_id)

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
  check_stop t;
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
  check_stop t;
  match t.latest with
  | Some f when pred f -> Effects.Holds f
  | _ -> wait_for_frames t w

let load_state t path =
  let r = Wire.load_state_result_of_json (call t (Wire.Load_state { path })) in
  t.load <- r.load;
  t.latest <- None;
  r.seq

let reset t =
  let r = Wire.load_state_result_of_json (call t Wire.Reset) in
  t.load <- r.load;
  t.latest <- None;
  r.seq

let save t request = Wire.save_result_of_json (call t request)

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
  | Effects.Race_held (commands, stop) ->
      Some (fun () -> race_held t commands stop)
  | Effects.Replace commands -> Some (fun () -> replace t commands)
  | Effects.Queue commands -> Some (fun () -> queue t commands)
  | Effects.Await (pred, timeout_ms) -> Some (fun () -> await t pred timeout_ms)
  | Effects.Now -> Some (fun () -> Option.value t.now ~default:0.)
  | Effects.Read -> Some (fun () -> t.latest)
  | Effects.Load_state path -> Some (fun () -> load_state t path)
  | Effects.Reset -> Some (fun () -> reset t)
  | Effects.Save_state path ->
      Some (fun () -> save t (Wire.Save_state { path }))
  | Effects.Save_frame path ->
      Some (fun () -> save t (Wire.Save_frame { path }))
  | Effects.Upload_template png -> Some (fun () -> upload_template t png)
  | Effects.Subscribe probes -> Some (fun () -> subscribe t probes)
  | Effects.Unsubscribe ids -> Some (fun () -> unsubscribe t ids)
  | Effects.Show_plan plan ->
      Some
        (fun () -> t.transport.send (Wire.Notification (Wire.Watch_plan plan)))
  | Effects.Show_log line ->
      Some
        (fun () -> t.transport.send (Wire.Notification (Wire.Watch_log line)))
  | Effects.Show_run run ->
      Some (fun () -> t.transport.send (Wire.Notification (Wire.Watch_run run)))
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

let acquire_lease t (owner, ttl_ms) =
  ignore
    (Wire.Lease.acquire_result_of_json
       (call t (Wire.Lease_acquire { owner; ttl_ms }))
      : Wire.Lease.t)

let run_with_backend ?(client = client_name) ?lease transport f =
  let t = create transport in
  let backend = hello ~client t in
  Option.iter (acquire_lease t) lease;
  handle t (fun () -> f backend)

let run ?client ?lease transport f =
  run_with_backend ?client ?lease transport (fun (_ : Wire.backend) -> f ())
