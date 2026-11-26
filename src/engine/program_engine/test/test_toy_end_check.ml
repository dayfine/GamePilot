(* A checkpoint's end check (the plan's "end": {"is": [flags]}) over the toy
   game: decoded and refused as the plan loads; before the first event, every
   flag holding passes the checkpoint with nothing run; after the last event,
   every flag must hold. The toy game's flags are fixed for a run, or turn on
   once an event has run. *)

open Toy_game
open Toy_engine

let talk = {|{"id": "greet", "kind": "talk"}|}
let rest = {|{"id": "sleep", "kind": "rest", "skip_if": ["rested"]}|}

let toy_plan ?(end_ = {|, "end": {"is": ["home"]}|}) ?(metadata = "{}") events =
  Printf.sprintf
    {|{"format": "gamepilot-checkpoint/1", "game": "toy", "execution": {},
       "checkpoint": {"id": "cf", "title": "Cat farm"%s,
         "metadata": %s, "events": [%s]}}|}
    end_ metadata
    (String.concat ", " events)

let decode text =
  Plan_decode.decode ~source:"toy.plan.json" (Yojson.Safe.from_string text)

let end_flags text =
  match decode text with
  | Ok plan -> "[" ^ String.concat "; " plan.checkpoint.end_flags ^ "]"
  | Error message -> message

let case name input expectation = { Table_test.name; input; expectation }

let decode_cases =
  [
    case "an end: its flags" (fun () -> end_flags (toy_plan [ talk ])) "[home]";
    case "no end: no flags"
      (fun () -> end_flags (toy_plan ~end_:"" [ talk ]))
      "[]";
    case "an end that names no flag: refused"
      (fun () -> end_flags (toy_plan ~end_:{|, "end": {"is": []}|} [ talk ]))
      "toy.plan.json: checkpoint.end.is is empty: an end names a flag.";
    case "an end with another field: refused"
      (fun () ->
        end_flags
          (toy_plan ~end_:{|, "end": {"is": ["home"], "at": "inn"}|} [ talk ]))
      "toy.plan.json: checkpoint.end.at is not a known field.";
    case "an end on a repeated checkpoint: refused"
      (fun () ->
        end_flags
          (toy_plan
             ~metadata:{|{"repeat": {"until": {"gold": 30}, "max_rounds": 2}}|}
             [ talk ]))
      "toy.plan.json: checkpoint.end is set on a repeated checkpoint: a round \
       ends where it starts.";
  ]

(* A toy game whose flags hold from the start ([flags]) or once an event of
   that id has run ([set_by]), logging each event it runs. *)
let toy_game ?(flags = []) ?(set_by = []) () =
  let lines = ref [] and held = ref flags in
  let log line = lines := line :: !lines in
  let ran (event : Plan.event) =
    log ("ran " ^ event.id);
    held :=
      List.map snd (List.filter (fun (id, _) -> id = event.id) set_by) @ !held;
    Ok ()
  in
  let game : Game.t =
    {
      run_own = (fun event _ -> ran event);
      run_builtin = ran;
      game_actions = [];
      flag_holds = (fun flag -> List.mem flag !held);
      position = (fun () -> None);
      between_rounds = (fun () -> Ok ());
      save = (fun () -> Ok ());
      reload = (fun () -> Ok ());
      log;
    }
  in
  (game, fun () -> List.rev !lines)

let plan () = Result.get_ok (decode (toy_plan [ talk; rest ]))

(* The run's outcome, then every line it logged (the runner's and the toy's
   "ran <event>") and every event's progress. *)
let run ?events ?flags ?set_by () =
  let game, lines = toy_game ?flags ?set_by () in
  let heard = ref [] in
  let on_event i (p : _ Engine_run.Event_progress.t) =
    let p =
      match p with
      | Started -> "started"
      | Passed -> "passed"
      | Skipped why -> "skipped (" ^ why ^ ")"
      | Failed _ -> "failed"
    in
    heard := Printf.sprintf "#%d %s" (i + 1) p :: !heard
  in
  let result = Runner.run ?events ~on_event game (plan ()).checkpoint in
  String.concat "\n"
    ((match result with Ok () -> "passed" | Error f -> Failure.to_string f)
     :: lines ()
    @ List.rev !heard)

let first_line text = List.hd (String.split_on_char '\n' text)

let run_cases =
  [
    case "at its end before the first event: passed, nothing run"
      (fun () -> run ~flags:[ "home" ] ())
      "passed\n\
       [Story] cf: start, 2 events\n\
       [Story] cf: already at its end (home): passed, no event run\n\
       #1 skipped (end: home)\n\
       #2 skipped (end: home)";
    case "not at its end: every event runs, then the end holds"
      (fun () -> run ~set_by:[ ("sleep", "home") ] ())
      "passed\n\
       [Story] cf: start, 2 events\n\
       [Story] cf #1 greet: start\n\
       ran greet\n\
       [Story] cf #1 greet: done\n\
       [Story] cf #2 sleep: start\n\
       ran sleep\n\
       [Story] cf #2 sleep: done\n\
       [End] cf home: passed: holds\n\
       [End] cf: 1 passed, 0 failed, 0 not checked: passed\n\
       [Story] cf: done\n\
       #1 started\n\
       #1 passed\n\
       #2 started\n\
       #2 passed";
    case "every event passed but the end does not hold: the run fails"
      (fun () -> first_line (run ()))
      "cf event 3 (end): postconditions unmet: home: failed: expected holds, \
       read does not hold";
    case "a run from the second event: the end is not checked before it"
      (fun () ->
        first_line (run ~events:{ first = 1; last = None } ~flags:[ "home" ] ()))
      "passed";
    case "a run from the second event: it runs, then the end is checked"
      (fun () ->
        String.concat ","
          (List.filter
             (fun l -> String.starts_with ~prefix:"ran" l)
             (String.split_on_char '\n'
                (run ~events:{ first = 1; last = None } ~flags:[ "home" ] ()))))
      "ran sleep";
    case "a run that stops before the last event: the end is not checked"
      (fun () -> first_line (run ~events:{ first = 0; last = Some 0 } ()))
      "passed";
  ]

let () = Table_test.run "toy_end_check" (decode_cases @ run_cases)
