(* Replays synthetic wire logs (fixtures/) through start_menu_poc, the same
   program the real handler runs. *)

let fixture name = Handler.Replay.log_of_file (Filename.concat "fixtures" name)
let state = Frlg.Start_menu_poc.default_state

let expect name ok =
  if ok then Printf.printf "ok %s\n" name else failwith ("FAILED " ^ name)

let contains s sub =
  let n = String.length sub in
  let rec go i =
    i + n <= String.length s && (String.sub s i n = sub || go (i + 1))
  in
  go 0

let () =
  let outcome =
    Handler.Replay.run
      (fixture "opens_closes.wirelog.jsonl")
      (Frlg.Start_menu_poc.run ~state)
  in
  print_endline (Frlg.Start_menu_poc.describe outcome);
  expect "Start opens, B closes"
    (match outcome with
    | Frlg.Start_menu_poc.Passed { opened_ms; closed_ms } ->
        opened_ms = 0. && closed_ms = 0.
    | _ -> false)

let () =
  let outcome =
    Handler.Replay.run
      (fixture "never_opens.wirelog.jsonl")
      (Frlg.Start_menu_poc.run ~state)
  in
  expect "menu never opens -> timeout"
    (outcome = Frlg.Start_menu_poc.Did_not_open)

let () =
  match
    Handler.Replay.run
      (fixture "pressed_a.wirelog.jsonl")
      (Frlg.Start_menu_poc.run ~state)
  with
  | _ -> failwith "FAILED divergence: replay accepted Start for a logged A"
  | exception Handler.Replay.Divergence e ->
      print_endline e;
      expect "different button -> divergence"
        (contains e "commands" && contains e "press Start"
       && contains e "press A")

(* A program that keeps waiting where the recorded client pressed a button
   must not read the frames that press caused. *)
let () =
  let waits_forever () =
    ignore (Kernel.load_state state : int);
    ignore (Kernel.subscribe [ Frlg.Start_menu.probe ] : string list);
    Kernel.await ~timeout_ms:60_000 (fun _ -> false)
  in
  match
    Handler.Replay.run (fixture "opens_closes.wirelog.jsonl") waits_forever
  with
  | _ -> failwith "FAILED divergence: await read past a client message"
  | exception Handler.Replay.Divergence e ->
      print_endline e;
      expect "await past a client message -> divergence"
        (contains e "recorded client sent submit")

(* The reader on the golden frame (open panel) and on overworld colors. *)
let () =
  let frame mean stddev : Kernel.measurements =
    {
      seq = 1;
      t_ms = 0.;
      probes = [ (Frlg.Start_menu.probe_id, Wire.Color_stats { mean; stddev }) ];
    }
  in
  let rgb r g b : Wire.rgb = { r; g; b } in
  expect "reader: white flat panel is open"
    (Frlg.Start_menu.start_menu_open
       (frame (rgb 248.1 248.0 247.9) (rgb 6.2 6.1 6.3)));
  expect "reader: red roof is closed"
    (not
       (Frlg.Start_menu.start_menu_open
          (frame (rgb 176.4 96.2 88.9) (rgb 48.3 41.7 39.5))));
  expect "reader: white but busy (text) is closed"
    (not
       (Frlg.Start_menu.start_menu_open
          (frame (rgb 230. 230. 230.) (rgb 60. 60. 60.))));
  expect "reader: missing probe is closed"
    (not (Frlg.Start_menu.start_menu_open { seq = 1; t_ms = 0.; probes = [] }))
