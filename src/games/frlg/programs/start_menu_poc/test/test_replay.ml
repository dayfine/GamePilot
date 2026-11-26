(* Replays synthetic wire logs (fixtures/) through start_menu_poc, the same
   program the real handler runs. *)

let fixture name = Replay.log_of_file (Filename.concat "fixtures" name)
let state = Start_menu_poc.default_state

let expect name ok =
  if ok then Printf.printf "ok %s\n" name else failwith ("FAILED " ^ name)

let () =
  let outcome =
    Replay.run
      (fixture "opens_closes.wirelog.jsonl")
      (Start_menu_poc.run ~state)
  in
  print_endline (Start_menu_poc.describe outcome);
  expect "Start opens, B closes"
    (match outcome with
    | Start_menu_poc.Passed { opened_ms; closed_ms } ->
        opened_ms = 0. && closed_ms = 0.
    | _ -> false)

let () =
  let outcome =
    Replay.run (fixture "never_opens.wirelog.jsonl") (Start_menu_poc.run ~state)
  in
  expect "menu never opens -> timeout" (outcome = Start_menu_poc.Did_not_open)

let () =
  match
    Replay.run (fixture "pressed_a.wirelog.jsonl") (Start_menu_poc.run ~state)
  with
  | _ -> failwith "FAILED divergence: replay accepted Start for a logged A"
  | exception Replay.Divergence e ->
      print_endline e;
      expect "different button -> divergence"
        (Strings.Contains.substring e "commands"
        && Strings.Contains.substring e "press Start"
        && Strings.Contains.substring e "press A")

(* A program whose wait never holds where the recorded client pressed a button
   times out there (the reader missed on the recorded frames) and must not read
   the frames that press caused; waiting again diverges. *)
let () =
  let waits_twice () =
    ignore (Effects.load_state state : int);
    ignore (Effects.subscribe [ Start_menu_poc.Menu_panel.probe ] : string list);
    let first = Effects.await ~timeout_ms:60_000 (fun _ -> false) in
    expect "await that never holds -> timeout at the recorded press"
      (first = Effects.Timeout);
    Effects.await ~timeout_ms:60_000 (fun _ -> false)
  in
  match Replay.run (fixture "opens_closes.wirelog.jsonl") waits_twice with
  | _ -> failwith "FAILED divergence: second await read past a client message"
  | exception Replay.Divergence e ->
      print_endline e;
      expect "second await past a client message -> divergence"
        (Strings.Contains.substring e "recorded client sent submit")

(* A wire log recorded live on mGBA (FireRed, Pallet overworld state): the
   program passes on it, so a reader change can be checked here without the
   emulator or the daemon. *)
let () =
  let outcome =
    Replay.run (fixture "mgba_run1.wirelog.jsonl") (Start_menu_poc.run ~state)
  in
  print_endline (Start_menu_poc.describe outcome);
  expect "recorded mGBA run passes"
    (match outcome with Start_menu_poc.Passed _ -> true | _ -> false)
