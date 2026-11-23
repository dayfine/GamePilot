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
    {|{"dir":"out","t_ms":0,"msg":{"jsonrpc":"2.0","id":1,"result":{"protocol":1,"daemon":"gamepilot-daemon/0.1","backend":{"kind":"mgba","game_code":"BPRE","frame_rate":59.7275,"width":240,"height":160},"probe_kinds":["core.color_stats@1"]}}}|};
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
