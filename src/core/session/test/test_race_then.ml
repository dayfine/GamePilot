(* Effects.race_then: the first frame on which [stop] holds sends one cancel
   with [then] (the commands [then_] made from that frame), no plain cancel,
   and the op returns once that batch's batch_done arrives. [then_] runs in the
   program: a log it performs reaches the session (console B, 2026-11-25: run
   3 of 01.03 died on Effect.Unhandled(Show_log) when [then_] ran inside the
   session's handler). *)

let expect name ok =
  if ok then Printf.printf "ok %s\n" name else failwith ("FAILED " ^ name)

let hello_result =
  {|{"protocol":1,"daemon":"gamepilot-daemon/0.1","backend":{"kind":"switch","game_code":"","frame_rate":60,"width":1920,"height":1080,"viewport":{"x":0,"y":0,"w":1,"h":1},"game_size":{"width":1920,"height":1080}},"probe_kinds":[]}|}

let frame seq =
  Session.Message
    (Wire.Notification
       (Wire.Frame
          { load = 0; frame = { seq; t_ms = float_of_int seq; probes = [] } }))

let batch_done batch_id =
  Session.Message
    (Wire.Notification (Wire.Batch_done { batch_id; seq = 9; t_ms = 9. }))

(* A daemon whose frames count up; a cancel with [then] is answered and that
   batch ends at once. *)
let fake_daemon () =
  let queue = Queue.create () and sent = ref [] and next = ref 0 in
  let reply id body =
    Queue.push
      (Session.Message
         (Wire.Response { id; outcome = Ok (Yojson.Safe.from_string body) }))
      queue
  in
  let send (m : Wire.message) =
    sent := m :: !sent;
    match m with
    | Wire.Request { id; call = Wire.Hello _ } -> reply id hello_result
    | Wire.Request { id; call = Wire.Submit { batch_id; _ } } ->
        reply id (Printf.sprintf {|{"batch_id":%S,"start_seq":1}|} batch_id)
    | Wire.Request { id; call = Wire.Cancel_then { batch_id; _ } } ->
        reply id {|{"released_seq":5}|};
        Queue.push (batch_done batch_id) queue
    | Wire.Request { id; _ } -> reply id "{}"
    | _ -> ()
  in
  let recv () =
    match Queue.take_opt queue with
    | Some ev -> ev
    | None ->
        incr next;
        frame !next
  in
  ({ Session.send; recv; wall_ms = (fun () -> 0.) }, sent)

let calls sent =
  List.filter_map
    (function Wire.Request { call; _ } -> Some call | _ -> None)
    (List.rev sent)

let () =
  let transport, sent = fake_daemon () in
  let hold = [ Wire.press ~hold_ms:5000 ~cooldown_ms:0 [ Wire.ZL ] ] in
  let move = [ Wire.press ~hold_ms:160 ~cooldown_ms:0 [ Wire.ZL; Wire.X ] ] in
  let raced =
    Session.run transport (fun () ->
        Effects.race_then hold
          ~stop:(fun m -> m.seq >= 3)
          ~then_:(fun m ->
            (* A log from inside the branch: it must reach the run's handler. *)
            Effects.show_log "picking the move";
            if m.seq = 3 then move else []))
  in
  expect "stopped on the third frame"
    (match raced with Effects.Stopped m -> m.seq = 3 | Finished _ -> false);
  let cancels =
    List.filter_map
      (function
        | Wire.Cancel -> Some None
        | Wire.Cancel_then { commands; _ } -> Some (Some commands)
        | _ -> None)
      (calls !sent)
  in
  expect "one cancel, with the move as its then" (cancels = [ Some move ]);
  expect "the branch's log went out as a watch log"
    (List.exists
       (function
         | Wire.Notification (Wire.Watch_log "picking the move") -> true
         | _ -> false)
       !sent)
