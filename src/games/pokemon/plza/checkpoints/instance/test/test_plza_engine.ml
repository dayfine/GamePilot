(* PLZA's rules through the engine (Plza_engine = Program_engine.Make
   over Plza_rules): 02-platform-to-plaza's plan decodes with zones and walks, a walk's args
   are checked as PokemonLZA_AutoStoryActionTable.cpp checks them (under our
   names), the runner sends a walk to
   the game's own handler and checks zones, and what a run keeps reads back. *)

open Plza_engine

let case name input expectation = { Table_test.name; input; expectation }

let plan_text ?(start = {|{"place": "LumioseCity"}|}) ?(postconditions = "{}")
    events =
  Printf.sprintf
    {|{"format": "gamepilot-checkpoint/1", "game": "plza", "execution": {},
       "checkpoint": {"id": "02-platform-to-plaza", "title": "The platform to Main Mission 01",
         "start": %s, "metadata": {"postconditions": %s},
         "events": [%s]}}|}
    start postconditions
    (String.concat ", " events)

let action id name =
  Printf.sprintf {|{"id": "%s", "kind": "game_action", "action": "%s"}|} id name

let walk ?(after = "") id args =
  Printf.sprintf {|{"id": "%s", "kind": "walk", "args": %s%s}|} id args
    (if after = "" then "" else {|, "declared_after": |} ^ after)

(* 02-platform-to-plaza as the C++ plan has it, its other actions game actions. *)
let platform_events =
  [
    action "on_platform" "wait_for_platform";
    action "text_speed_fast" "set_text_speed_fast";
    walk "platform_to_plaza"
      {|{"legs": [[0, 4500], [90, 10000]], "end": "fade_white"}|}
      ~after:{|{"place": "LumioseCity", "spot": "plaza"}|};
    {|{"id": "arrival_to_ad", "kind": "scene"}|};
    action "skip_ad" "plus_skip";
    {|{"id": "arrival_scenes", "kind": "scene"}|};
  ]

let decode text =
  Plan_decode.decode ~source:"plza-01.01.plan.json"
    (Yojson.Safe.from_string text)

let decoded show text =
  match decode text with Ok plan -> show plan | Error message -> message

let plan () = Result.get_ok (decode (plan_text platform_events))
let event id () = Plan_text.event_named (plan ()) id

(* One walk event's text, or the decoder's error. *)
let walk_args args =
  decoded (fun p -> Plan_text.event_named p "w") (plan_text [ walk "w" args ])

let decode_cases =
  [
    case
      "02-platform-to-plaza's outline: a zone start, a walk among the engine's \
       kinds"
      (fun () -> Plan_text.outline (plan ()))
      "plza 02-platform-to-plaza from LumioseCity: 3 game_action, 1 walk, 2 \
       scene";
    case "the walk to the plaza: its legs, its end, a zone declared after"
      (event "platform_to_plaza")
      "platform_to_plaza: walk [0, 4500] [90, 10000] until fade_white => \
       LumioseCity/plaza";
    case "steered, a wait before, and an end not before a time"
      (fun () ->
        walk_args
          {|{"legs": [[-66, 600]], "style": "steer", "wait_before_ms": 500, "end": "dialog", "earliest_end_ms": 300}|})
      "w: walk [-66, 600] steer after 500 ms until dialog not before 300 ms";
    case "a style that is not one of the two"
      (fun () -> walk_args {|{"legs": [[0, 1]], "style": "held"}|})
      "plza-01.01.plan.json: checkpoint.events[0].args.style must be \
       \"face_then_walk\" or \"steer\".";
    case "a heading to face first (the fork's, a minimap bearing)"
      (fun () ->
        walk_args
          {|{"legs": [[0, 6500], [-90, 13000]], "end": "dialog", "heading": 257}|})
      "w: walk [0, 6500] [-90, 13000] facing 257 until dialog";
    case "until a scene"
      (fun () -> walk_args {|{"legs": [[0, 1000]], "end": "scene"}|})
      "w: walk [0, 1000] until scene";
    case "no postconditions: PLZA promises none"
      (fun () -> Plan_text.postconditions (plan ()))
      "none";
    case "a leg that is not [angle, ms]"
      (fun () -> walk_args {|{"legs": [[0, 1000], [90]]}|})
      "plza-01.01.plan.json: checkpoint.events[0].args.legs[1] is not [angle \
       degrees, walk ms].";
    case "legs are required"
      (fun () -> walk_args {|{"end": "scene"}|})
      "plza-01.01.plan.json: checkpoint.events[0].args.legs is missing.";
    case "an end that is not one of the seven"
      (fun () -> walk_args {|{"legs": [[0, 1]], "end": "banner"}|})
      "plza-01.01.plan.json: checkpoint.events[0].args.end must be \
       \"fade_white\", \"fade_black\", \"dialog\", \"prompt\", \"talk\", \
       \"talk_after_legs\" or \"scene\".";
    case "earliest_end_ms needs an end"
      (fun () -> walk_args {|{"legs": [[0, 1]], "earliest_end_ms": 100}|})
      "plza-01.01.plan.json: checkpoint.events[0].args.earliest_end_ms needs \
       an \"end\" other than a talk.";
    case "a walk into a talk after its legs"
      (fun () ->
        walk_args
          {|{"legs": [[-66, 600]], "style": "steer", "end": "talk_after_legs"}|})
      "w: walk [-66, 600] steer into a talk after the legs";
    case "an unknown walk arg"
      (fun () -> walk_args {|{"legs": [[0, 1]], "tiles": 3}|})
      "plza-01.01.plan.json: checkpoint.events[0].args.tiles is not a known \
       field.";
    case "a grid pose is not a PLZA pose"
      (fun () ->
        decoded Plan_text.outline (plan_text ~start:{|{"map": "Town"}|} []))
      "plza-01.01.plan.json: checkpoint.start.map is not a known field.";
    case "a Pokémon kind is not PLZA's"
      (fun () ->
        decoded Plan_text.outline
          (plan_text [ {|{"id": "x", "kind": "legs", "args": {"legs": []}}|} ]))
      {|plza-01.01.plan.json: checkpoint.events[0].kind "legs" is not a story event kind.|};
    case "a promise PLZA cannot read"
      (fun () ->
        decoded Plan_text.outline
          (plan_text ~postconditions:{|{"party": []}|} []))
      "plza-01.01.plan.json: checkpoint.metadata.postconditions.party is not a \
       known field.";
  ]

let at ?spot place : Pose.zone = { place; spot }

(* A PLZA game that logs each handler and stands where the script says after
   each event; [position] is [None] when it reads no zone. *)
let plza_game ?(after = []) ?(reads_zone = true) () =
  let lines = ref [] and here = ref (at "LumioseCity" ~spot:"platform") in
  let log line = lines := line :: !lines in
  let handled what (event : Plan.event) =
    log what;
    Option.iter (fun p -> here := p) (List.assoc_opt event.id after);
    Ok ()
  in
  let action name = (name, fun event _ -> handled ("action " ^ name) event) in
  let game : Game.t =
    {
      run_own =
        (fun event own ->
          handled ("own " ^ Plza_rules.Action.to_string own) event);
      run_builtin = (fun event -> handled ("builtin " ^ event.id) event);
      game_actions =
        List.map action
          [ "wait_for_platform"; "set_text_speed_fast"; "plus_skip" ];
      flag_holds = (fun _ -> false);
      position = (fun () -> if reads_zone then Some !here else None);
      between_rounds = (fun () -> Ok ());
      save = (fun () -> Ok (log "save"));
      reload = (fun () -> Ok (log "reload"));
      log;
    }
  in
  (game, fun () -> List.rev !lines)

let handler_lines lines =
  List.filter (fun l -> not (String.starts_with ~prefix:"[" l)) lines

let plaza = [ ("platform_to_plaza", at "LumioseCity" ~spot:"plaza") ]

let run_result ?end_at ?after ?reads_zone () =
  let game, lines = plza_game ?after ?reads_zone () in
  let result = Runner.run ?end_at game (plan ()).checkpoint in
  ( (match result with Ok () -> "passed" | Error f -> Failure.to_string f),
    lines () )

let outcome ?end_at ?after ?reads_zone () =
  fst (run_result ?end_at ?after ?reads_zone ())

let run_cases =
  [
    case "each event to its handler: the walk to PLZA's own"
      (fun () ->
        String.concat "\n" (handler_lines (snd (run_result ~after:plaza ()))))
      "action wait_for_platform\n\
       action set_text_speed_fast\n\
       own walk [0, 4500] [90, 10000] until fade_white\n\
       builtin arrival_to_ad\n\
       action plus_skip\n\
       builtin arrival_scenes";
    case "the zone declared after the walk, where the player stands: passed"
      (fun () -> outcome ~after:plaza ())
      "passed";
    case "the zone declared after, elsewhere: the walk fails"
      (fun () -> outcome ())
      "02-platform-to-plaza event 3 (platform_to_plaza): declared after at \
       LumioseCity/plaza, but the game reads LumioseCity/platform";
    case "a game that reads no zone (PLZA today): nothing to check, passed"
      (fun () -> outcome ~reads_zone:false ())
      "passed";
    case "a declared end zone without a spot holds anywhere in its place"
      (fun () -> outcome ~after:plaza ~end_at:(at "LumioseCity") ())
      "passed";
  ]

let kept : Saved.t = { at = Some (at "LumioseCity" ~spot:"plaza") }

let kept_cases =
  [
    case "what is kept beside a state: the zone"
      (fun () -> Yojson.Safe.to_string (Saved.to_yojson kept))
      {|{"at":{"place":"LumioseCity","spot":"plaza"}}|};
    case "what is kept reads back as written"
      (fun () ->
        match Saved.of_yojson (Saved.to_yojson kept) with
        | Ok back -> string_of_bool (back = kept)
        | Error e -> e)
      "true";
  ]

let () = Table_test.run "plza_engine" (decode_cases @ run_cases @ kept_cases)
