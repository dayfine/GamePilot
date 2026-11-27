(* The watch page's Stop: once the daemon's [stop] arrives, the program's next
   wait on the game raises Stop_requested, while plain requests (the failure
   path's saves) still run. The program's watch notifications go out as such. *)

let expect name ok =
  if ok then Printf.printf "ok %s\n" name else failwith ("FAILED " ^ name)

let hello_result =
  {|{"protocol":1,"daemon":"gamepilot-daemon/0.1","backend":{"kind":"mgba","game_code":"BPRE","frame_rate":59.7275,"width":240,"height":160,"viewport":{"x":0,"y":0,"w":1,"h":1},"game_size":{"width":240,"height":160}},"probe_kinds":[]}|}

(* The daemon's answer to each request, by method. *)
let answer (call : Wire.call) =
  Yojson.Safe.from_string
    (match call with
    | Wire.Hello _ -> hello_result
    | Wire.Submit { batch_id; _ } ->
        Printf.sprintf {|{"batch_id":%S,"start_seq":1}|} batch_id
    | Wire.Save_frame _ -> {|{"seq":7}|}
    | _ -> "{}")

let frame seq =
  Session.Message
    (Wire.Notification
       (Wire.Frame
          { load = 0; frame = { seq; t_ms = float_of_int seq; probes = [] } }))

let stop = Session.Message (Wire.Notification (Wire.Stop "stopped by user"))

(* A daemon that answers every request at once and otherwise plays [script];
   after it, frames keep coming (a game that never shows what is awaited). *)
let fake_daemon script =
  let queue = Queue.of_seq (List.to_seq script) in
  let sent = ref [] and next = ref 1000 in
  let send (m : Wire.message) =
    sent := m :: !sent;
    match m with
    | Wire.Request { id; call } ->
        Queue.push
          (Session.Message (Wire.Response { id; outcome = Ok (answer call) }))
          queue
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

let raises_stop f =
  match f () with
  | _ -> false
  | exception Effects.Stop_requested reason -> reason = "stopped by user"

let never _ = false

let () =
  let transport, _ = fake_daemon [ frame 1; frame 2; stop; frame 3 ] in
  expect "stop during an await ends the program with Stop_requested"
    (raises_stop (fun () ->
         Session.run transport (fun () ->
             Effects.await ~timeout_ms:1_000_000 never)))

(* The batch never ends (the daemon dropped it when it released the buttons). *)
let () =
  let transport, _ = fake_daemon [ frame 1; stop ] in
  expect "stop during a submit ends the program with Stop_requested"
    (raises_stop (fun () ->
         Session.run transport (fun () ->
             Effects.submit [ Wire.Wait { wait_ms = 100_000 } ])))

let () =
  let transport, _ = fake_daemon [ stop ] in
  let commands = [ Wire.Wait { wait_ms = 100_000 } ] in
  expect "stop during a race ends the program with Stop_requested"
    (raises_stop (fun () ->
         Session.run transport (fun () -> Effects.race commands ~stop:never)))

(* The stop stays: a program that catches it and waits again is stopped
   again; its saves still run. *)
let () =
  let transport, _ = fake_daemon [ stop ] in
  let program () =
    (try ignore (Effects.await ~timeout_ms:1_000_000 never : Effects.awaited)
     with Effects.Stop_requested _ -> ());
    let saved = Effects.save_frame "failure.png" in
    expect "a save after the stop still runs" (saved = 7);
    Effects.await ~timeout_ms:1_000_000 never
  in
  expect "a second wait after the stop is stopped too"
    (raises_stop (fun () -> Session.run transport program))

let () =
  let transport, sent = fake_daemon [] in
  let plan =
    {
      Wire.Watch.checkpoint = "mg-01";
      events = [ { (Wire.Watch.pending "ready") with state = Current } ];
    }
  in
  Session.run transport (fun () ->
      Effects.show_plan plan;
      Effects.show_log "[Run] mg-01 #1 ready: start");
  expect "show_plan and show_log go out as watch notifications"
    (match !sent with
    | [
     Wire.Notification (Wire.Watch_log "[Run] mg-01 #1 ready: start");
     Wire.Notification (Wire.Watch_plan p);
     Wire.Request _;
    ] ->
        p = plan
    | _ -> false)
