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
   batch ends at once. With [ends_submits], a submitted batch ends after the
   next frame too. *)
let fake_daemon ?(ends_submits = false) () =
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
        reply id (Printf.sprintf {|{"batch_id":%S,"start_seq":1}|} batch_id);
        if ends_submits then (
          incr next;
          Queue.push (frame !next) queue;
          Queue.push (batch_done batch_id) queue)
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

(* Effects.queue: a submit answered with no wait for its batch_done; the
   next queued at once, and a later submit waits for its own batch_done only.
   The fake daemon ends no submitted batch by itself, so a queue that waited
   would hang here. *)
let () =
  let transport, sent = fake_daemon () in
  let zl ms = [ Wire.press ~hold_ms:ms ~cooldown_ms:0 [ Wire.ZL ] ] in
  let seen =
    Session.run transport (fun () ->
        Effects.queue (zl 1000);
        let m = Effects.await ~timeout_ms:100 (fun m -> m.seq >= 2) in
        Effects.queue (zl 1000);
        m)
  in
  expect "queue: reads while the batch runs"
    (match seen with Effects.Holds m -> m.seq = 2 | Timeout -> false);
  let submits =
    List.filter_map
      (function Wire.Submit { commands; _ } -> Some commands | _ -> None)
      (calls !sent)
  in
  expect "queue: two submits, no cancel"
    (submits = [ zl 1000; zl 1000 ]
    && not
         (List.exists
            (function Wire.Cancel | Wire.Cancel_then _ -> true | _ -> false)
            (calls !sent)))

(* Effects.race_then where the stop never holds: the batch runs to its end,
   [then_] is never called and no cancel is sent. *)
let () =
  let transport, sent = fake_daemon ~ends_submits:true () in
  let hold = [ Wire.press ~hold_ms:160 ~cooldown_ms:0 [ Wire.ZL ] ] in
  let called = ref false in
  let raced =
    Session.run transport (fun () ->
        Effects.race_then hold
          ~stop:(fun _ -> false)
          ~then_:(fun _ ->
            called := true;
            []))
  in
  expect "race_then, no stop: the batch finished"
    (match raced with Effects.Finished _ -> true | Stopped _ -> false);
  expect "race_then, no stop: then_ not called, no cancel"
    ((not !called)
    && not
         (List.exists
            (function Wire.Cancel | Wire.Cancel_then _ -> true | _ -> false)
            (calls !sent)))

(* Effects.Replace with no batch held: a plain submit, ended by its own
   batch_done. *)
let () =
  let transport, sent = fake_daemon ~ends_submits:true () in
  let tap = [ Wire.press ~hold_ms:80 ~cooldown_ms:0 [ Wire.A ] ] in
  let done_ =
    Session.run transport (fun () -> Effect.perform (Effects.Replace tap))
  in
  let submits =
    List.filter_map
      (function
        | Wire.Submit { batch_id; commands; _ } -> Some (batch_id, commands)
        | _ -> None)
      (calls !sent)
  in
  expect "replace, none held: one submit, no cancel"
    (List.map snd submits = [ tap ]
    && not
         (List.exists
            (function Wire.Cancel | Wire.Cancel_then _ -> true | _ -> false)
            (calls !sent)));
  expect "replace, none held: ends on that submit's batch_done"
    (List.map fst submits = [ done_.Wire.batch_id ])
