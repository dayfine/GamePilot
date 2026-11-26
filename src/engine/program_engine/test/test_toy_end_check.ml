(* A checkpoint already at its end, over the toy game: the runner reads the
   promises of where it ends (the toy's sign, Toy_rules.end_place) before the
   first event and, when they pass, runs no event and passes, as Repeat_until
   runs no round once its goal holds. Its gold, a change, is not read then. A
   run from a later event does not check it, nor a toy whose promises name no
   sign; a repeated checkpoint cannot promise one. *)

open Toy_game
open Toy_engine

let talk = {|{"id": "greet", "kind": "talk"}|}
let rest = {|{"id": "sleep", "kind": "rest"}|}

let toy_plan ?(postconditions = {|{"sign": "inn", "gold": 30}|}) ?(repeat = "")
    () =
  Printf.sprintf
    {|{"format": "gamepilot-checkpoint/1", "game": "toy", "execution": {},
       "checkpoint": {"id": "cf", "title": "Cat farm",
         "metadata": {"postconditions": %s%s},
         "events": [%s, %s]}}|}
    postconditions repeat talk rest

let decode text =
  Plan_decode.decode ~source:"toy.plan.json" (Yojson.Safe.from_string text)

let case name input expectation = { Table_test.name; input; expectation }

(* A toy game that logs each event it runs; the sign in sight is [sign] until
   an event runs, then [after]. *)
let toy_game ~sign ~after =
  let lines = ref [] and in_sight = ref sign and moved = ref false in
  let log line = lines := line :: !lines in
  let ran (event : Plan.event) =
    log ("ran " ^ event.id);
    in_sight := after;
    moved := true;
    Ok ()
  in
  let game : Game.t =
    {
      run_own = (fun event _ -> ran event);
      run_builtin = ran;
      game_actions = [];
      flag_holds = (fun _ -> false);
      position = (fun () -> None);
      between_rounds = (fun () -> Ok ());
      save = (fun () -> Ok ());
      reload = (fun () -> Ok ());
      log;
    }
  in
  (game, in_sight, moved, fun () -> List.rev !lines)

(* The run's outcome, every line it logged and every event's progress. Gold
   reads 50 at the start and 80 once an event ran; [read_gold] counts the
   reads that asked for it. *)
let run ?events ?postconditions ?(sign = None) ?(after = Some "inn") () =
  let plan = Result.get_ok (decode (toy_plan ?postconditions ())) in
  let game, in_sight, moved, lines = toy_game ~sign ~after in
  let gold_reads = ref 0 in
  let observe (p : Toy_rules.Postconditions.t) : Toy_rules.Postconditions.reads
      =
    if p.promises.gold <> None then incr gold_reads;
    {
      gold_now = Some (if !moved then 80 else 50);
      start = Some 50;
      set = [];
      in_sight = !in_sight;
    }
  in
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
  let end_state = Option.map (fun p -> (p, observe)) plan.postconditions in
  let result = Runner.run ?end_state ?events ~on_event game plan.checkpoint in
  String.concat "\n"
    ((match result with Ok () -> "passed" | Error f -> Failure.to_string f)
     :: lines ()
    @ List.rev !heard
    @ [ Printf.sprintf "gold read %d" !gold_reads ])

let first_line text = List.hd (String.split_on_char '\n' text)

(* The run's lines that start with [prefix], joined by commas. *)
let starting prefix text =
  String.concat ","
    (List.filter (String.starts_with ~prefix) (String.split_on_char '\n' text))

let at_end () = run ~sign:(Some "inn") ()

let cases =
  [
    case "at its end before the first event: passed"
      (fun () -> first_line (at_end ()))
      "passed";
    case "at its end before the first event: logged with the sign read"
      (fun () -> starting "[Run] cf: already" (at_end ()))
      "[Run] cf: already at its end (sign inn): passed, no event run";
    case "at its end before the first event: no event runs"
      (fun () -> starting "ran" (at_end ()))
      "";
    case "at its end before the first event: every event skipped as at its end"
      (fun () -> starting "#" (at_end ()))
      "#1 skipped (at its end),#2 skipped (at its end)";
    case "at its end before the first event: gold, a change, is not read"
      (fun () -> starting "gold read" (at_end ()))
      "gold read 0";
    case "not at its end: every event runs, then the promises are checked"
      (fun () -> first_line (run ()))
      "passed";
    case "not at its end: the end's promises read once, after the last event"
      (fun () -> List.nth (List.rev (String.split_on_char '\n' (run ()))) 0)
      "gold read 1";
    case "another sign in sight before the first event: the events run"
      (fun () -> starting "ran" (run ~sign:(Some "well") ()))
      "ran greet,ran sleep";
    case "the events run but the sign is not in sight: the end fails"
      (fun () -> first_line (run ~after:None ()))
      "cf event 3 (postconditions): postconditions unmet: sign: failed: \
       expected inn, read none";
    case "a run from the second event: not checked before it"
      (fun () ->
        starting "ran"
          (run ~events:{ first = 1; last = None } ~sign:(Some "inn") ()))
      "ran sleep";
    case "promises with no sign: no end place, the events run"
      (fun () -> starting "ran" (run ~postconditions:{|{"gold": 30}|} ()))
      "ran greet,ran sleep";
    case "a repeated checkpoint promising a sign: refused"
      (fun () ->
        match
          decode
            (toy_plan
               ~repeat:{|, "repeat": {"until": {"gold": 30}, "max_rounds": 2}|}
               ())
        with
        | Ok _ -> "decoded"
        | Error e -> e)
      "toy.plan.json: checkpoint.metadata.postconditions name an end place on \
       a repeated checkpoint: a round ends where it starts.";
  ]

let () = Table_test.run "toy_end_check" cases
