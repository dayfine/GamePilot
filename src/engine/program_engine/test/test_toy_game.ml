(* The engine over a toy game built from the engine's pieces, with zones and
   no grid (Toy_rules, Toy_plan_format, Toy_event_snapshot): its plans decode with
   the toy's zones, action sets and promises, the runner sends each action to
   its handler and checks zones and promises, and what a run keeps and loops
   works on the toy's types. Test_toy_pieces tests the pieces' own parts. *)

open Toy_game
open Toy_engine

let toy_plan ?(start = {|{"place": "Village", "spot": "inn"}|})
    ?(postconditions =
      {|{"position": {"place": "Forest"}, "gold": 30, "flags": ["met_cat"]}|})
    events =
  Printf.sprintf
    {|{"format": "gamepilot-checkpoint/1", "game": "toy", "execution": {},
       "checkpoint": {"id": "cf", "title": "Cat farm", "start": %s,
         "metadata": {"postconditions": %s},
         "events": [%s]}}|}
    start postconditions
    (String.concat ", " events)

let walk =
  {|{"id": "into_forest", "kind": "walk", "args": {"toward": "north", "until": "forest_sign"},
     "declared_after": {"place": "Forest"}}|}

let talk = {|{"id": "greet", "kind": "talk"}|}
let answer = {|{"id": "agree", "kind": "answer", "args": {"yes": false}}|}

let beg =
  {|{"id": "beg", "kind": "game_action", "action": "beg", "args": {"item": "bell"}}|}

let rest = {|{"id": "sleep", "kind": "rest", "skip_if": ["rested"]}|}
let buy = {|{"id": "bell", "kind": "buy", "args": {"item": "bell"}}|}
let events = [ walk; talk; answer; beg; rest; buy ]

let decode text =
  Plan_decode.decode ~source:"toy.plan.json" (Yojson.Safe.from_string text)

let decoded show text =
  match decode text with Ok plan -> show plan | Error message -> message

let plan () = Result.get_ok (decode (toy_plan events))
let event id () = Plan_text.event_named (plan ()) id
let case name input expectation = { Table_test.name; input; expectation }

let decode_cases =
  [
    case
      "a toy plan's outline: a zone start, the toy's actions and the engine's \
       kinds"
      (fun () -> Plan_text.outline (plan ()))
      "toy cf from Village/inn: 1 walk, 1 talk, 1 answer, 1 game_action, 1 \
       rest, 1 buy";
    case "a walk: the toy's walk action, with a zone declared after"
      (event "into_forest")
      "into_forest: walk north until forest_sign => Forest";
    case "an answer: the engine's kind" (event "agree") "agree: answer no";
    case "a game action: its args as written" (event "beg")
      {|beg: [beg] game_action {"item":"bell"}|};
    case "a rest: the toy's inn set, without args" (event "sleep")
      "sleep: rest skip_if rested";
    case "a buy: the toy's inn set, with its item" (event "bell")
      "bell: buy bell";
    case "the toy's promises: the position first, then the toy's"
      (fun () -> Plan_text.postconditions (plan ()))
      "position Forest\ngold gained 30\nflags met_cat";
    case "no postconditions: the toy's none"
      (fun () ->
        decoded Plan_text.postconditions
          (toy_plan ~postconditions:"{}" [ talk ]))
      "none";
    case "a kind neither the engine's nor the toy's"
      (fun () ->
        decoded Plan_text.outline
          (toy_plan [ {|{"id": "x", "kind": "route"}|} ]))
      {|toy.plan.json: checkpoint.events[0].kind "route" is not a story event kind.|};
    case "an unknown arg of the toy's walk action, named by its set's decoder"
      (fun () ->
        decoded Plan_text.outline
          (toy_plan
             [
               {|{"id": "x", "kind": "walk", "args": {"toward": "n", "until": "s", "tiles": 3}}|};
             ]))
      "toy.plan.json: checkpoint.events[0].args.tiles is not a known field.";
    case "a grid pose is not a toy pose"
      (fun () ->
        decoded Plan_text.outline (toy_plan ~start:{|{"map": "Town"}|} [ talk ]))
      "toy.plan.json: checkpoint.start.map is not a known field.";
    case "a promised position that is not a zone: the zone's decoder names it"
      (fun () ->
        decoded Plan_text.outline
          (toy_plan ~postconditions:{|{"position": {"map": "Town"}}|} [ talk ]))
      "toy.plan.json: checkpoint.metadata.postconditions.position.map is not a \
       known field.";
    case "a promise the toy cannot read"
      (fun () ->
        decoded Plan_text.outline
          (toy_plan ~postconditions:{|{"party": []}|} [ talk ]))
      "toy.plan.json: checkpoint.metadata.postconditions.party is not a known \
       field.";
  ]

let at place spot : Toy_rules.Pose.t = { place; spot }

(* A toy game that logs each handler and stands where the script says after
   each event. *)
let toy_game ?(after = []) ?(flags = []) () =
  let lines = ref [] and here = ref (at "Village" (Some "inn")) in
  let log line = lines := line :: !lines in
  let handled what (event : Plan.event) =
    log what;
    Option.iter (fun p -> here := p) (List.assoc_opt event.id after);
    Ok ()
  in
  let game : Game.t =
    {
      run_own =
        (fun event own ->
          handled ("own " ^ Toy_rules.Action.to_string own) event);
      run_builtin = (fun event -> handled ("builtin " ^ event.id) event);
      game_actions = [ ("beg", fun event _ -> handled "action beg" event) ];
      flag_holds = (fun flag -> List.mem flag flags);
      position = (fun () -> Some !here);
      between_rounds = (fun () -> Ok (log "between rounds"));
      save = (fun () -> Ok (log "save"));
      reload = (fun () -> Ok (log "reload"));
      log;
    }
  in
  (game, fun () -> List.rev !lines)

(* The handler lines of the log, without the runner's own. *)
let handler_lines lines =
  List.filter (fun l -> not (String.starts_with ~prefix:"[" l)) lines

let forest = [ ("into_forest", at "Forest" None) ]

let run_result ?end_at ?end_state ?after ?flags () =
  let game, lines = toy_game ?after ?flags () in
  let result = Runner.run ?end_at ?end_state game (plan ()).checkpoint in
  ( (match result with Ok () -> "passed" | Error f -> Failure.to_string f),
    lines () )

let outcome ?end_at ?end_state ?after ?flags () =
  fst (run_result ?end_at ?end_state ?after ?flags ())

let reads gold_now : Toy_rules.Postconditions.reads =
  { gold_now = Some gold_now; start = Some 50; set = [ "met_cat" ] }

let promised () = Option.get (plan ()).postconditions

(* The zone a plan's postconditions promise, as the runner's declared end. *)
let promised_position ?at () =
  let plan =
    match at with
    | None -> plan ()
    | Some zone ->
        Result.get_ok
          (decode
             (toy_plan
                ~postconditions:(Printf.sprintf {|{"position": %s}|} zone)
                events))
  in
  Toy_rules.position (Option.get plan.postconditions)

let run_cases =
  [
    case "each kind goes to its handler; a skipped one runs nothing"
      (fun () ->
        String.concat "\n"
          (handler_lines
             (snd (run_result ~after:forest ~flags:[ "rested" ] ()))))
      "own walk north until forest_sign\n\
       builtin greet\n\
       builtin agree\n\
       action beg\n\
       own buy bell";
    case "a zone declared after, where the player stands: passed"
      (fun () -> outcome ~after:forest ())
      "passed";
    case "a zone declared after, where the player is not: the event fails"
      (fun () -> outcome ())
      "cf event 1 (into_forest): declared after at Forest, but the game reads \
       Village/inn";
    case "the declared end zone, where the player stands: passed"
      (fun () -> outcome ~after:forest ~end_at:(at "Forest" None) ())
      "passed";
    case "the declared end zone, elsewhere: the end fails"
      (fun () -> outcome ~after:forest ~end_at:(at "Village" (Some "inn")) ())
      "cf event 7 (end): declared end at Village/inn, but the game reads Forest";
    case
      "the promised zone as the declared end, where the player stands: passed"
      (fun () -> outcome ~after:forest ?end_at:(promised_position ()) ())
      "passed";
    case "the promised zone as the declared end, elsewhere: the end fails"
      (fun () ->
        outcome ~after:forest
          ?end_at:(promised_position ~at:{|{"place": "Village"}|} ())
          ())
      "cf event 7 (end): declared end at Village, but the game reads Forest";
    case "the toy's promises, held: passed"
      (fun () ->
        outcome ~after:forest ~end_state:(promised (), fun _ -> reads 80) ())
      "passed";
    case "the toy's promises, unmet: the run fails naming them"
      (fun () ->
        outcome ~after:forest ~end_state:(promised (), fun _ -> reads 70) ())
      "cf event 7 (postconditions): postconditions unmet: gold: failed: \
       expected gained 30, read gained 20 (50 to 70)";
    case "the promises' log line"
      (fun () ->
        let _, lines =
          run_result ~after:forest
            ~end_state:(promised (), fun _ -> reads 80)
            ()
        in
        List.find (String.starts_with ~prefix:"[Postcondition] cf gold") lines)
      "[Postcondition] cf gold: passed: gained 30 (50 to 80)";
  ]

let kept : Toy_event_snapshot.t =
  { Engine_event_snapshot.Kept.start = Some 50; at = Some (at "Forest" None) }

let kept_cases =
  [
    case "what is kept beside a state: the toy's start reads and zone"
      (fun () -> Yojson.Safe.to_string (Toy_event_snapshot.to_yojson kept))
      {|{"start_gold":50,"at":{"place":"Forest","spot":null}}|};
    case "what is kept reads back as written"
      (fun () ->
        match
          Toy_event_snapshot.of_yojson (Toy_event_snapshot.to_yojson kept)
        with
        | Ok back -> string_of_bool (back = kept)
        | Error e -> e)
      "true";
    case "an older file without the start reads: the start unread"
      (fun () ->
        match Toy_event_snapshot.of_yojson (`Assoc [ ("at", `Null) ]) with
        | Ok { start = None; at = None } -> "unread, nowhere"
        | Ok _ -> "read"
        | Error e -> e)
      "unread, nowhere";
    case "a kept zone the toy cannot read: the derived reader names its type"
      (fun () ->
        match Toy_event_snapshot.of_yojson (`Assoc [ ("at", `Int 1) ]) with
        | Ok _ -> "read"
        | Error e -> e)
      "Zone_snapshot.t";
  ]

(* Two rounds until the goal holds: the toy's between-rounds runs after each. *)
let repeat_rounds () =
  let game, lines = toy_game ~after:forest () in
  let rounds = ref 0 in
  let goal () = Ok (!rounds >= 2) in
  let game = { game with save = (fun () -> Ok (incr rounds)) } in
  let limits = { Repeat_until.max_rounds = 3; attempts_per_round = 1 } in
  match Repeat_until.run limits ~goal game (plan ()).checkpoint with
  | Ok n ->
      Printf.sprintf "%d rounds, %d between" n
        (List.length (List.filter (( = ) "between rounds") (lines ())))
  | Error stop -> Repeat_until.stop_to_string stop

let () =
  Table_test.run "toy_game"
    (decode_cases @ run_cases @ kept_cases
    @ [
        case "a repeat: between rounds after each" repeat_rounds
          "2 rounds, 2 between";
      ])
