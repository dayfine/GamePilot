(* Session and replay rules on short hand-written wire logs. *)

let expect name ok =
  if ok then Printf.printf "ok %s\n" name else failwith ("FAILED " ^ name)

let contains s sub =
  let n = String.length sub in
  let rec go i =
    i + n <= String.length s && (String.sub s i n = sub || go (i + 1))
  in
  go 0

let hello =
  [
    {|{"dir":"in","t_ms":0,"msg":{"jsonrpc":"2.0","id":1,"method":"hello","params":{"protocol":1,"client":"gamepilot-programs/0.1"}}}|};
    {|{"dir":"out","t_ms":0,"msg":{"jsonrpc":"2.0","id":1,"result":{"protocol":1,"daemon":"gamepilot-daemon/0.1","backend":{"kind":"mgba","game_code":"BPRE","frame_rate":59.7275,"width":240,"height":160,"viewport":{"x":0,"y":0,"w":1,"h":1},"game_size":{"width":240,"height":160}},"probe_kinds":["core.color_stats@1"]}}}|};
    {|{"dir":"in","t_ms":0,"msg":{"jsonrpc":"2.0","id":2,"method":"backend.load_state","params":{"path":"state.ss"}}}|};
    {|{"dir":"out","t_ms":1,"msg":{"jsonrpc":"2.0","id":2,"result":{"seq":500,"load":2}}}|};
  ]

let frame ~seq ~load =
  Printf.sprintf
    {|{"dir":"out","t_ms":%d,"msg":{"jsonrpc":"2.0","method":"frame","params":{"seq":%d,"load":%d,"t_ms":%d,"probes":{}}}}|}
    seq seq load seq

(* A frame from before the load that arrives after its reply shows the old
   state; await must skip it. *)
let () =
  let log =
    Replay.log_of_lines
      (hello @ [ frame ~seq:9000 ~load:1; frame ~seq:501 ~load:2 ])
  in
  let first_frame () =
    ignore (Effects.load_state "state.ss" : int);
    Effects.await ~timeout_ms:1000 (fun _ -> true)
  in
  expect "frame from before load_state is ignored"
    (match Replay.run log first_frame with
    | Effects.Holds m -> m.seq = 501
    | Effects.Timeout -> false)

(* A program that stops before sending every recorded request diverges and
   names the first request it did not send. *)
let () =
  let log =
    Replay.log_of_lines
      (hello
      @ [
          {|{"dir":"in","t_ms":2,"msg":{"jsonrpc":"2.0","id":3,"method":"submit","params":{"batch_id":"b1","commands":[{"press":["A"],"hold_ms":100,"cooldown_ms":100}]}}}|};
        ])
  in
  match Replay.run log (fun () -> Effects.load_state "state.ss") with
  | _ -> failwith "FAILED replay accepted a run missing a recorded submit"
  | exception Replay.Divergence e ->
      print_endline e;
      expect "missing recorded request -> divergence"
        (contains e "line 5" && contains e "submit (id 3)")

(* A reader that misses on the recorded frames times out where the live run
   pressed next; the program then fails on its own path, which is its outcome,
   not a divergence, even though it never sends the recorded press. *)
let () =
  let log =
    Replay.log_of_lines
      (hello
      @ [
          frame ~seq:501 ~load:2;
          {|{"dir":"in","t_ms":2,"msg":{"jsonrpc":"2.0","id":3,"method":"submit","params":{"batch_id":"b1","commands":[{"press":["B"],"hold_ms":100,"cooldown_ms":100}]}}}|};
          frame ~seq:502 ~load:2;
        ])
  in
  let reader_misses () =
    ignore (Effects.load_state "state.ss" : int);
    Effects.await ~timeout_ms:1000 (fun _ -> false)
  in
  expect "reader miss -> program's own timeout, not a divergence"
    (match Replay.run log reader_misses with
    | Effects.Timeout -> true
    | Effects.Holds _ -> false)

(* [race]: a batch run while a reader watches the frames. *)

let submit_b1 =
  [
    {|{"dir":"in","t_ms":2,"msg":{"jsonrpc":"2.0","id":3,"method":"submit","params":{"batch_id":"b1","commands":[{"press":["Up"],"hold_ms":500,"cooldown_ms":0}]}}}|};
    {|{"dir":"out","t_ms":2,"msg":{"jsonrpc":"2.0","id":3,"result":{"batch_id":"b1","start_seq":501}}}|};
  ]

let batch_done ~batch_id ~seq =
  Printf.sprintf
    {|{"dir":"out","t_ms":%d,"msg":{"jsonrpc":"2.0","method":"batch_done","params":{"batch_id":"%s","seq":%d,"t_ms":%d}}}|}
    seq batch_id seq seq

let cancel_request ~id =
  Printf.sprintf
    {|{"dir":"in","t_ms":0,"msg":{"jsonrpc":"2.0","id":%d,"method":"cancel","params":{}}}|}
    id

let cancel_reply ~id ~seq =
  Printf.sprintf
    {|{"dir":"out","t_ms":%d,"msg":{"jsonrpc":"2.0","id":%d,"result":{"released_seq":%d}}}|}
    seq id seq

let hold_up = [ Wire.press ~hold_ms:500 ~cooldown_ms:0 [ Up ] ]

(* Stops on the frame numbered [seq]. *)
let race_until_seq seq () =
  ignore (Effects.load_state "state.ss" : int);
  Effects.race hold_up ~stop:(fun m -> m.seq = seq)

let raced_text = function
  | Effects.Finished d -> Printf.sprintf "finished %s at %d" d.batch_id d.seq
  | Effects.Stopped m -> Printf.sprintf "stopped at %d" m.seq

(* No frame stops it: the batch's batch_done ends the race, and nothing is
   cancelled. *)
let () =
  let log =
    Replay.log_of_lines
      (hello @ submit_b1
      @ [
          frame ~seq:501 ~load:2;
          frame ~seq:502 ~load:2;
          batch_done ~batch_id:"b1" ~seq:530;
        ])
  in
  let r = raced_text (Replay.run log (race_until_seq 999)) in
  print_endline r;
  expect "race without a stop -> finished" (r = "finished b1 at 530")

(* The reader holds on frame 502: the program cancels there, and the frames
   after the stop are not the program's business. *)
let () =
  let log =
    Replay.log_of_lines
      (hello @ submit_b1
      @ [
          frame ~seq:501 ~load:2;
          frame ~seq:502 ~load:2;
          cancel_request ~id:4;
          frame ~seq:503 ~load:2;
          cancel_reply ~id:4 ~seq:503;
        ])
  in
  let r = raced_text (Replay.run log (race_until_seq 502)) in
  print_endline r;
  expect "race stopped mid-batch -> cancel sent" (r = "stopped at 502")

(* The batch ended on its way while the cancel was in flight: its batch_done
   comes before the cancel's reply, and the race still says stopped. The next
   batch then runs to its own batch_done, not the stale one. *)
let () =
  let log =
    Replay.log_of_lines
      (hello @ submit_b1
      @ [
          frame ~seq:502 ~load:2;
          cancel_request ~id:4;
          batch_done ~batch_id:"b1" ~seq:503;
          frame ~seq:503 ~load:2;
          cancel_reply ~id:4 ~seq:503;
          {|{"dir":"in","t_ms":3,"msg":{"jsonrpc":"2.0","id":5,"method":"submit","params":{"batch_id":"b2","commands":[{"press":["Up"],"hold_ms":500,"cooldown_ms":0}]}}}|};
          {|{"dir":"out","t_ms":3,"msg":{"jsonrpc":"2.0","id":5,"result":{"batch_id":"b2","start_seq":504}}}|};
          batch_done ~batch_id:"b2" ~seq:534;
        ])
  in
  let stop_then_submit () =
    let first = race_until_seq 502 () in
    let latest = match Effects.read () with Some m -> m.seq | None -> -1 in
    let second = Effects.submit hold_up in
    Printf.sprintf "%s, latest %d, then %s at %d" (raced_text first) latest
      second.batch_id second.seq
  in
  let r = Replay.run log stop_then_submit in
  print_endline r;
  expect "batch_done before the cancel reply -> stopped, next batch its own"
    (r = "stopped at 502, latest 503, then b2 at 534")

(* The reader misses the frame the live run stopped on: the program waits on
   while the recorded client cancelled, which is a divergence, not a pass. *)
let () =
  let log =
    Replay.log_of_lines
      (hello @ submit_b1
      @ [
          frame ~seq:502 ~load:2;
          cancel_request ~id:4;
          cancel_reply ~id:4 ~seq:503;
        ])
  in
  match Replay.run log (race_until_seq 999) with
  | r -> failwith ("FAILED replay accepted a missed stop: " ^ raced_text r)
  | exception Replay.Divergence e ->
      print_endline e;
      expect "missed stop -> divergence" (contains e "cancel (id 4)")

(* [probe.upload_template]: each PNG goes up once per connection, and a replay
   checks the bytes the program uploads against the recorded ones. *)

let hash_a = String.make 64 'a'

let upload_png_a =
  [
    {|{"dir":"in","t_ms":2,"msg":{"jsonrpc":"2.0","id":3,"method":"probe.upload_template","params":{"png":"cG5nLUE="}}}|};
    Printf.sprintf
      {|{"dir":"out","t_ms":2,"msg":{"jsonrpc":"2.0","id":3,"result":{"template":"%s"}}}|}
      hash_a;
  ]

let upload_twice second () =
  ignore (Effects.load_state "state.ss" : int);
  let first = Effects.upload_template "png-A" in
  (first, Effects.upload_template second)

(* The second upload of the same bytes sends nothing (the log has one
   request) and returns the first hash. *)
let () =
  let log = Replay.log_of_lines (hello @ upload_png_a) in
  let first, second = Replay.run log (upload_twice "png-A") in
  expect "same template twice -> one upload, same hash"
    (first = hash_a && second = hash_a)

(* A program that uploads other bytes than the live run did diverges. *)
let () =
  let log = Replay.log_of_lines (hello @ upload_png_a) in
  match
    Replay.run log (fun () ->
        ignore (Effects.load_state "state.ss" : int);
        Effects.upload_template "png-B")
  with
  | _ -> failwith "FAILED replay accepted an upload of other bytes"
  | exception Replay.Divergence e ->
      print_endline e;
      expect "other template bytes -> divergence"
        (contains e "line 5" && contains e "template differs")

(* [unsubscribe]: [with_probes] unsubscribes after the reader is done, the
   latest frame drops the probe, and a replay checks the ids. *)

let subscribe_p_then_unsubscribe =
  [
    {|{"dir":"in","t_ms":2,"msg":{"jsonrpc":"2.0","id":3,"method":"subscribe","params":{"probes":[{"id":"p","kind":"core.color_stats@1","box":{"x":0,"y":0,"w":1,"h":1},"delivery":"latest"}]}}}|};
    {|{"dir":"out","t_ms":2,"msg":{"jsonrpc":"2.0","id":3,"result":{"subscribed":["p"]}}}|};
    {|{"dir":"out","t_ms":3,"msg":{"jsonrpc":"2.0","method":"frame","params":{"seq":502,"load":2,"t_ms":3,"probes":{"p":{"kind":"core.color_stats@1","mean":[1,2,3],"stddev":[0,0,0]}}}}}|};
    {|{"dir":"in","t_ms":4,"msg":{"jsonrpc":"2.0","id":4,"method":"unsubscribe","params":{"ids":["p"]}}}|};
    {|{"dir":"out","t_ms":4,"msg":{"jsonrpc":"2.0","id":4,"result":{"unsubscribed":["p"]}}}|};
  ]

let p_probe =
  Wire.color_stats_probe ~id:"p"
    ~box:{ x = 0.; y = 0.; w = 1.; h = 1. }
    ~delivery:Latest

let read_p_once ~unsubscribe_ids () =
  ignore (Effects.load_state "state.ss" : int);
  ignore (Effects.subscribe [ p_probe ] : string list);
  let has_p m = Effects.probe m "p" <> None in
  let awaited = Effects.await ~timeout_ms:1000 has_p in
  ignore (Effects.unsubscribe unsubscribe_ids : string list);
  (awaited, Effects.read ())

let () =
  let log = Replay.log_of_lines (hello @ subscribe_p_then_unsubscribe) in
  let read_with_probes () =
    ignore (Effects.load_state "state.ss" : int);
    let awaited =
      Effects.with_probes [ p_probe ] (fun () ->
          Effects.await ~timeout_ms:1000 (fun m -> Effects.probe m "p" <> None))
    in
    (awaited, Effects.read ())
  in
  expect "with_probes unsubscribes; the latest frame drops the probe"
    (match Replay.run log read_with_probes with
    | Effects.Holds _, Some latest -> Effects.probe latest "p" = None
    | _ -> false)

let () =
  let log = Replay.log_of_lines (hello @ subscribe_p_then_unsubscribe) in
  match Replay.run log (read_p_once ~unsubscribe_ids:[ "q" ]) with
  | _ -> failwith "FAILED replay accepted an unsubscribe of other ids"
  | exception Replay.Divergence e ->
      print_endline e;
      expect "other unsubscribe ids -> divergence" (contains e "ids differs")

(* v1.4: a frame carries only the results that changed; the session keeps the
   others, so a reader still sees every subscribed probe. *)
let () =
  let stats mean =
    Printf.sprintf
      {|{"kind":"core.color_stats@1","mean":[%d,0,0],"stddev":[0,0,0]}|} mean
  in
  let frame_with ~seq probes =
    Printf.sprintf
      {|{"dir":"out","t_ms":%d,"msg":{"jsonrpc":"2.0","method":"frame","params":{"seq":%d,"load":2,"t_ms":%d,"probes":{%s}}}}|}
      seq seq seq probes
  in
  let log =
    Replay.log_of_lines
      (hello
      @ [
          frame_with ~seq:501
            (Printf.sprintf {|"p":%s,"q":%s|} (stats 1) (stats 2));
          frame_with ~seq:502 (Printf.sprintf {|"q":%s|} (stats 3));
          frame_with ~seq:503 "";
        ])
  in
  let red m id =
    match Effects.probe m id with
    | Some (Wire.Color_stats { mean; _ }) -> Some mean.r
    | _ -> None
  in
  let third_frame () =
    ignore (Effects.load_state "state.ss" : int);
    Effects.await ~timeout_ms:1000 (fun m -> m.seq = 503)
  in
  expect "a frame keeps the results it does not repeat"
    (match Replay.run log third_frame with
    | Effects.Holds m ->
        red m "p" = Some 1.
        && red m "q" = Some 3.
        && List.map fst m.probes = [ "p"; "q" ]
    | Effects.Timeout -> false)

(* A stopped run replays as it ran: the logged stop ends the program's wait
   at the same point, and its watch notifications, which the daemon keeps off
   the wire log, are not expected there. *)
let () =
  let log =
    Replay.log_of_lines
      (hello
      @ [
          frame ~seq:501 ~load:2;
          {|{"dir":"out","t_ms":502,"msg":{"jsonrpc":"2.0","method":"stop","params":{"reason":"stopped by user"}}}|};
          frame ~seq:503 ~load:2;
        ])
  in
  let program () =
    ignore (Effects.load_state "state.ss" : int);
    Effects.show_log "[Story] waiting";
    Effects.await ~timeout_ms:100_000 (fun _ -> false)
  in
  expect "a logged stop replays as Stop_requested"
    (match Replay.run log program with
    | _ -> false
    | exception Effects.Stop_requested r -> r = "stopped by user")

(* A daemon that served two clients logs both; the replay follows the program
   (the connection that spoke first) and skips the other's lines, frames
   included. *)
let () =
  let on conn line =
    "{\"conn\":" ^ string_of_int conn ^ ","
    ^ String.sub line 1 (String.length line - 1)
  in
  let ctl_status =
    {|{"dir":"in","t_ms":1,"msg":{"jsonrpc":"2.0","id":1,"method":"status","params":{}}}|}
  in
  let log =
    Replay.log_of_lines
      (List.map (on 1) hello
      @ [
          on 2 ctl_status;
          on 2 (frame ~seq:7777 ~load:2);
          on 1 (frame ~seq:502 ~load:2);
        ])
  in
  let first_frame () =
    ignore (Effects.load_state "state.ss" : int);
    Effects.await ~timeout_ms:1000 (fun _ -> true)
  in
  expect "replay follows the program's connection"
    (match Replay.run log first_frame with
    | Effects.Holds m -> m.seq = 502
    | Effects.Timeout -> false)

(* v1.12: a press with sticks shows them when it diverges from the log. *)
let () =
  let log = Replay.log_of_lines (hello @ submit_b1) in
  let up = Result.get_ok (Wire.stick 0. 1.) in
  let run () =
    ignore (Effects.load_state "state.ss" : int);
    Effects.submit
      [ Wire.press ~left_stick:up ~hold_ms:500 ~cooldown_ms:0 [ B ] ]
  in
  match Replay.run log run with
  | _ -> failwith "FAILED a stick press replayed as the recorded Up press"
  | exception Replay.Divergence e ->
      print_endline e;
      expect "stick press -> divergence naming the stick"
        (contains e "press B left 0,1 hold 500")
