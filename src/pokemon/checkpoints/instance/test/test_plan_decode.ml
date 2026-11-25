(* Plan_decode reads every PokemonSimulation FireRed plan, types each built-in
   kind's args, and rejects a broken plan naming the field. The Mail Glitch
   plans are read through FireRed's loader, in its test_mail_glitch_plans. *)

open Pokemon_engine

let load_all paths =
  let errors =
    List.filter_map
      (fun path ->
        Result.fold
          ~ok:(fun _ -> None)
          ~error:Option.some (Plan_decode.load path))
      paths
  in
  match (paths, errors) with
  | [], _ -> "no plans"
  | _, [] -> "all decode"
  | _, first :: _ ->
      Printf.sprintf "%d of %d fail; first: %s" (List.length errors)
        (List.length paths) first

let load name dir =
  match Plan_decode.load (Filename.concat dir name) with
  | Ok plan -> plan
  | Error message -> failwith message

let outline name dir = Plan_text.outline (load name dir)
let event name dir id = Plan_text.event_named (load name dir) id
let authored = Plan_files.authored_dir

let base =
  {|{"format": "gamepilot-checkpoint/1", "game": "test", "execution": {"menu": "full"},
  "checkpoint": {"id": "cp", "title": "Test", "start": {"map": "Town", "tiles": [[1, 2]], "facing": "south"},
    "events": [
      {"id": "walk", "kind": "route", "action": "run", "args": {"target": {"map": "Town", "tiles": [[4, 0]], "facing": "north"}}, "why": "to the door"},
      {"id": "buy", "kind": "game_action", "action": "mart", "args": {"map": "Mart", "budget": 3000}},
      {"id": "no", "kind": "answer", "args": {"yes": false}},
      {"id": "turn", "kind": "step", "args": {"direction": "east"}},
      {"id": "ok", "kind": "answer"},
      {"id": "fight", "kind": "battle"}]}}|}

(* The base plan with the first [find] replaced. *)
let edited find replacement =
  let n = String.length find in
  let rec at i =
    if i + n > String.length base then failwith ("not in the base plan: " ^ find)
    else if String.sub base i n = find then
      String.sub base 0 i ^ replacement
      ^ String.sub base (i + n) (String.length base - i - n)
    else at (i + 1)
  in
  at 0

let base_events =
  String.concat "\n"
    [
      "Town (1, 2) south";
      "walk: [run] route to Town (4, 0) north";
      {|buy: [mart] game_action {"map":"Mart","budget":3000}|};
      "no: answer no";
      "turn: step east";
      "ok: answer yes";
      "fight: battle";
    ]

let decoded text =
  match
    Plan_decode.decode ~source:"base.plan.json" (Yojson.Safe.from_string text)
  with
  | Ok plan ->
      String.concat "\n"
        (Option.fold ~none:"(no start)" ~some:Plan_text.pose
           plan.checkpoint.start
        :: List.map Plan_text.event plan.checkpoint.events)
  | Error message -> message

let error name (find, replacement) expectation =
  {
    Table_test.name;
    input = (fun () -> decoded (edited find replacement));
    expectation;
  }

let at = "base.plan.json: checkpoint."

let real_plans : Table_test.case list =
  [
    {
      name = "every PokemonSimulation FireRed plan";
      input = (fun () -> load_all (Plan_files.plans_in authored));
      expectation = "all decode";
    };
    {
      name = "a plan with no start (new game)";
      input = (fun () -> outline "frlg-00.01.plan.json" authored);
      expectation = "frlg 00.01 from (no start): 1 new_game, 1 game_settings";
    };
    {
      name = "legs that fight wild Pokemon";
      input = (fun () -> event "frlg-00.08.plan.json" authored "forest_east");
      expectation =
        "forest_east: legs fighting east 1, north 4, east 14, north 15";
    };
    {
      name = "skip_if";
      input =
        (fun () -> event "frlg-00.24.plan.json" authored "route6_south_path");
      expectation =
        "route6_south_path: [run] route to Route6 (11, 34) north skip_if \
         surge_winnable";
    };
  ]

let inline_plans : Table_test.case list =
  [
    {
      name = "built-in args typed, fallbacks filled in";
      input = (fun () -> decoded base);
      expectation = base_events;
    };
    {
      name = "the format's old name";
      input =
        (fun () ->
          decoded
            (edited {|"gamepilot-checkpoint/1"|}
               {|"pokesim-authored-checkpoint/1"|}));
      expectation = base_events;
    };
    {
      name = "a zone start";
      input =
        (fun () ->
          decoded
            (edited {|{"map": "Town", "tiles": [[1, 2]], "facing": "south"}|}
               {|{"place": "Plaza", "heading": 90}|}));
      expectation =
        "zone Plaza" ^ String.sub base_events 17 (String.length base_events - 17);
    };
    {
      name = "a route that fights trainers";
      input =
        (fun () ->
          decoded
            (edited {|"facing": "north"}}|}
               {|"facing": "north"}, "fight_trainers": true}|}));
      expectation =
        String.concat "\n"
          (List.map
             (fun line ->
               if line = "walk: [run] route to Town (4, 0) north" then
                 line ^ " fighting trainers"
               else line)
             (String.split_on_char '\n' base_events));
    };
    {
      name = "not an object";
      input = (fun () -> decoded "[]");
      expectation = "base.plan.json is not a JSON object.";
    };
    error "wrong format"
      ( {|"format": "gamepilot-checkpoint/1"|},
        {|"format": "pokesim-story-plan/1"|} )
      {|base.plan.json: format is "pokesim-story-plan/1", not gamepilot-checkpoint/1.|};
    error "no execution"
      ({|"execution": {"menu": "full"},|}, "")
      "base.plan.json: execution is missing.";
    error "unknown envelope field"
      ({|"game": "test",|}, {|"game": "test", "notes": [],|})
      "base.plan.json: notes is not a known field.";
    error "no checkpoint id" ({|"id": "cp", |}, "") (at ^ "id is missing.");
    error "empty checkpoint id"
      ({|"id": "cp"|}, {|"id": ""|})
      (at ^ "id is empty.");
    error "unknown event field"
      ({|"id": "walk",|}, {|"id": "walk", "colour": 1,|})
      (at ^ "events[0].colour is not a known field.");
    error "unknown kind"
      ({|"kind": "battle"|}, {|"kind": "dance"|})
      (at ^ {|events[5].kind "dance" is not a story event kind.|});
    error "route without a target"
      ( {|{"target": {"map": "Town", "tiles": [[4, 0]], "facing": "north"}}|},
        "{}" )
      (at ^ "events[0].args.target is missing.");
    error "target tile not a pair" ("[[4, 0]]", "[[4]]")
      (at ^ "events[0].args.target.tiles[0] is not [x, y].");
    error "target facing not a direction"
      ({|"facing": "north"|}, {|"facing": "up"|})
      (at
     ^ {|events[0].args.target.facing "up" is not north, east, south or west.|}
      );
    error "game action without its name"
      ({|"action": "mart", |}, "")
      (at ^ "events[1].action is missing: a game_action names its action.");
    error "unknown built-in arg"
      ({|{"yes": false}|}, {|{"yes": false, "loud": true}|})
      (at ^ "events[2].args.loud is not a known field.");
    error "answer not true or false"
      ({|"yes": false|}, {|"yes": "no"|})
      (at ^ "events[2].args.yes is not true or false.");
    error "args on a kind that takes none"
      ({|"kind": "battle"|}, {|"kind": "talk", "args": {"who": "nurse"}|})
      (at ^ "events[5].args.who is not a known field.");
    error "repeated event id"
      ({|"id": "turn"|}, {|"id": "walk"|})
      (at ^ {|events[3].id "walk" repeats events[0].|});
    error "start with a map and a place"
      ( {|"start": {"map": "Town",|},
        {|"start": {"place": "Plaza", "map": "Town",|} )
      (at ^ {|start has a "map" or a "place", not both or neither.|});
    {
      name = "a start anywhere outdoors";
      input =
        (fun () ->
          decoded
            (edited {|{"map": "Town", "tiles": [[1, 2]], "facing": "south"},|}
               {|{"anywhere": "outdoors"},|}));
      expectation =
        String.concat "\n"
          ("anywhere outdoors"
          :: List.tl (String.split_on_char '\n' base_events));
    };
    error "a start anywhere in an unknown class"
      ( {|{"map": "Town", "tiles": [[1, 2]], "facing": "south"},|},
        {|{"anywhere": "indoors"},|} )
      (at ^ {|start.anywhere "indoors" is not a class of places ("outdoors").|});
    error "a start anywhere with a map too"
      ({|{"map": "Town",|}, {|{"anywhere": "outdoors", "map": "Town",|})
      (at ^ "start.map is not a known field.");
    error "an event's pose is one place, never anywhere"
      ( {|{"id": "fight", "kind": "battle"}|},
        {|{"id": "fight", "kind": "battle", "declared_after": {"anywhere": "outdoors"}}|}
      )
      (at
     ^ {|events[5].declared_after has a "map" or a "place", not both or neither.|}
      );
  ]

let with_postconditions json =
  let text =
    edited {|"title": "Test",|}
      (Printf.sprintf
         {|"title": "Test", "metadata": {"phase": "testing", "postconditions": %s},|}
         json)
  in
  match
    Plan_decode.decode ~source:"base.plan.json" (Yojson.Safe.from_string text)
  with
  | Ok plan -> Plan_text.postconditions plan
  | Error message -> message

let post = at ^ "metadata.postconditions."

let postcondition_cases : Table_test.case list =
  [
    {
      name = "every postcondition, PokemonSimulation's and ours";
      input =
        (fun () ->
          with_postconditions
            {|{"position": {"map": "Town", "tiles": [[3, 4]]}, "party_includes": ["abra", "abra"],
               "items": [{"item": "retro-mail", "quantity": 2}], "coins": 20,
               "money": {"min": 100, "max": 200}, "flags": ["got_coin_case"],
               "knows": [{"species": "mr-mime", "moves": ["recycle"]}],
               "levels": [{"species": "mr-mime", "min": 33}]}|});
      expectation =
        "position Town (3, 4)\n\
         party includes abra, abra\n\
         item retro-mail x2\n\
         coins x20\n\
         money 100 to 200\n\
         flags got_coin_case\n\
         mr-mime knows recycle\n\
         mr-mime at least Lv 33";
    };
    {
      name = "party in order and party_includes, not both";
      input =
        (fun () ->
          with_postconditions
            {|{"party": ["abra"], "party_includes": ["abra"]}|});
      expectation =
        post ^ "party and party_includes: one or the other, not both.";
    };
    {
      name = "party_includes with the slots a plan depends on";
      input =
        (fun () ->
          with_postconditions
            {|{"party_includes": ["pidgey"], "party_slots": [{"slot": 1, "species": "mr-mime"}]}|});
      expectation = "party includes pidgey\nmr-mime in slot 1";
    };
    {
      name = "party_slots alone: only the slots";
      input =
        (fun () ->
          with_postconditions
            {|{"party_slots": [{"slot": 1, "species": "mr-mime"}]}|});
      expectation = "mr-mime in slot 1";
    };
    {
      name = "party_slots with party, which names every slot";
      input =
        (fun () ->
          with_postconditions
            {|{"party": ["abra"], "party_slots": [{"slot": 1, "species": "abra"}]}|});
      expectation = post ^ "party_slots goes with party_includes, not party.";
    };
    {
      name = "a party slot past six";
      input =
        (fun () ->
          with_postconditions
            {|{"party_slots": [{"slot": 7, "species": "abra"}]}|});
      expectation = post ^ "party_slots[0].slot 7 is not a party slot (1-6).";
    };
    {
      name = "money min above max";
      input =
        (fun () -> with_postconditions {|{"money": {"min": 5, "max": 4}}|});
      expectation = post ^ "money.min 5 is above max 4.";
    };
    {
      name = "money spent";
      input = (fun () -> with_postconditions {|{"money": {"spent": 4100}}|});
      expectation = "money spent 4100";
    };
    {
      name = "money spent and a range";
      input =
        (fun () ->
          with_postconditions {|{"money": {"spent": 4100, "min": 1, "max": 2}}|});
      expectation = post ^ "money: give min and max, or spent, not both.";
    };
    {
      name = "money with neither a range nor spent";
      input = (fun () -> with_postconditions {|{"money": {}}|});
      expectation = post ^ "money: give min and max, or spent.";
    };
    {
      name = "a level without its min";
      input =
        (fun () -> with_postconditions {|{"levels": [{"species": "mr-mime"}]}|});
      expectation = post ^ "levels[0].min is missing.";
    };
    {
      name = "counts gained, used and at least, and coins gained";
      input =
        (fun () ->
          with_postconditions
            {|{"items": [{"item": "escape-rope", "gained": 1}, {"item": "retro-mail", "used": 1},
                         {"item": "revive", "at_least": 2}], "coins": {"gained": 20}}|});
      expectation =
        "item escape-rope gained 1\n\
         item retro-mail used 1\n\
         item revive at least 2\n\
         coins gained 20";
    };
    {
      name = "an item with a quantity and a gain";
      input =
        (fun () ->
          with_postconditions
            {|{"items": [{"item": "escape-rope", "quantity": 3, "gained": 1}]}|});
      expectation =
        post ^ "items[0]: give one of quantity, gained, used, at_least.";
    };
    {
      name = "an item with no count";
      input =
        (fun () -> with_postconditions {|{"items": [{"item": "escape-rope"}]}|});
      expectation =
        post ^ "items[0]: give one of quantity, gained, used, at_least.";
    };
    {
      name = "caught at least, and caught gained";
      input =
        (fun () ->
          with_postconditions {|{"caught": {"at_least": 60}}|}
          ^ "\n"
          ^ with_postconditions {|{"caught": {"gained": 2}}|});
      expectation = "caught at least 60\ncaught gained 2";
    };
    {
      name = "caught as a word";
      input = (fun () -> with_postconditions {|{"caught": "sixty"}|});
      expectation = post ^ "caught is not a number or a JSON object.";
    };
    {
      name = "coins as an object with no count";
      input = (fun () -> with_postconditions {|{"coins": {}}|});
      expectation = post ^ "coins: give one of exactly, gained, used, at_least.";
    };
    {
      name = "a mark no party shows";
      input = (fun () -> with_postconditions {|{"marks": ["none", "berry"]}|});
      expectation = post ^ "marks: berry is not held_item, mail or none.";
    };
    {
      name = "an unknown postcondition";
      input = (fun () -> with_postconditions {|{"badges": 3}|});
      expectation = post ^ "badges is not a known field.";
    };
  ]

let retries_of metadata =
  let text =
    edited {|"title": "Test",|}
      (Printf.sprintf {|"title": "Test", "metadata": %s,|} metadata)
  in
  match
    Plan_decode.decode ~source:"base.plan.json" (Yojson.Safe.from_string text)
  with
  | Ok plan -> string_of_int plan.retries
  | Error message -> message

let retries_cases : Table_test.case list =
  let case name input expectation : Table_test.case =
    { name; input; expectation }
  in
  [
    case "no retries field: none"
      (fun () -> retries_of {|{"phase": "testing"}|})
      "0";
    case "negative retries are refused"
      (fun () -> retries_of {|{"retries": -1}|})
      (at ^ "metadata.retries is -1, not 0 or more.");
  ]

let repeat_of metadata =
  let text =
    edited {|"title": "Test",|}
      (Printf.sprintf {|"title": "Test", "metadata": %s,|} metadata)
  in
  match
    Plan_decode.decode ~source:"base.plan.json" (Yojson.Safe.from_string text)
  with
  | Ok plan -> Plan_text.repeat plan
  | Error message -> message

let repeat_cases : Table_test.case list =
  let case name input expectation : Table_test.case =
    { name; input; expectation }
  in
  [
    case "no repeat field: none"
      (fun () -> repeat_of {|{"phase": "testing"}|})
      "no repeat";
    case "max_rounds below 1 is refused"
      (fun () -> repeat_of {|{"repeat": {"until": {}, "max_rounds": 0}}|})
      (at ^ "metadata.repeat.max_rounds is 0, not 1 or more.");
    case "until is required"
      (fun () -> repeat_of {|{"repeat": {"max_rounds": 3}}|})
      (at ^ "metadata.repeat.until is missing.");
    case "rounds until 60 species caught"
      (fun () ->
        repeat_of
          {|{"repeat": {"until": {"caught": {"at_least": 60}}, "max_rounds": 8}}|})
      "at most 8 rounds, until:\ncaught at least 60";
    case "an unknown goal field is refused"
      (fun () ->
        repeat_of {|{"repeat": {"until": {"badges": 3}, "max_rounds": 3}}|})
      (at ^ "metadata.repeat.until.badges is not a known field.");
  ]

let () =
  Table_test.run "plan_decode"
    (real_plans @ inline_plans @ postcondition_cases @ retries_cases
   @ repeat_cases)
