(* Plan_decode reads every PokemonSimulation FireRed plan and the Mail Glitch
   plans that need no FireRed expansion (places, fragments: the program
   registry's test loads every program plan through FireRed's Plan_file), types
   each built-in kind's args, and rejects a broken plan naming the field. *)

open Checkpoints

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

(* A plan's id, start, and how many events of each kind, in first-seen order. *)
let outline name dir =
  let plan = load name dir in
  let counts =
    List.fold_left
      (fun counts (e : Plan.event) ->
        let k = Plan_text.kind_name e.kind in
        if List.mem_assoc k counts then
          List.map
            (fun (k', n) -> if k' = k then (k', n + 1) else (k', n))
            counts
        else counts @ [ (k, 1) ])
      [] plan.checkpoint.events
  in
  Printf.sprintf "%s %s from %s: %s" plan.game plan.checkpoint.checkpoint_id
    (Option.fold ~none:"(no start)" ~some:Plan_text.declared
       plan.checkpoint.start)
    (String.concat ", "
       (List.map (fun (k, n) -> Printf.sprintf "%d %s" n k) counts))

let event name dir id =
  let plan = load name dir in
  Plan_text.event
    (List.find (fun (e : Plan.event) -> e.id = id) plan.checkpoint.events)

let mg = Plan_files.mail_glitch_dir
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
        (Option.fold ~none:"(no start)" ~some:Plan_text.declared
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
      name = "mg-02 outline";
      input = (fun () -> outline "mg-02.plan.json" mg);
      expectation =
        "frlg mg-02 from CeladonCity (39, 21) south: 7 route, 6 game_action, 1 \
         scene";
    };
    {
      name = "mg-04b outline: one grind round";
      input = (fun () -> outline "mg-04b.plan.json" mg);
      expectation =
        "frlg mg-04b from IndigoPlateau_PokemonCenter_1F (13, 12) north: 1 \
         game_action";
    };
    {
      name = "mg-04c outline";
      input = (fun () -> outline "mg-04c.plan.json" mg);
      expectation =
        "frlg mg-04c from IndigoPlateau_PokemonCenter_1F (13, 12) north: 2 \
         route, 1 game_action";
    };
    {
      name = "mg-05a outline";
      input = (fun () -> outline "mg-05a.plan.json" mg);
      expectation =
        "frlg mg-05a from LavenderTown (18, 7) south: 9 route, 12 game_action, \
         1 scene";
    };
    {
      name = "mg-05 outline";
      input = (fun () -> outline "mg-05.plan.json" mg);
      expectation = "frlg mg-05 from Route16 (30, 7) north: 2 game_action";
    };
    {
      name = "a plan with no start (new game)";
      input = (fun () -> outline "frlg-00.01.plan.json" authored);
      expectation = "frlg 00.01 from (no start): 1 new_game, 1 options";
    };
    {
      name = "a route's typed target";
      input = (fun () -> event "mg-02.plan.json" mg "to_route16_cut_tree");
      expectation = "to_route16_cut_tree: [run] route to Route16 (41, 12) north";
    };
    {
      name = "a game action keeps its args as JSON, and its declared_after";
      input = (fun () -> event "mg-02.plan.json" mg "fly_vermilion");
      expectation =
        {|fly_vermilion: [fly] game_action {"town":"VermilionCity","species":"pidgey"} => VermilionCity (15, 7) south|};
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
  ]

(* A plan's postconditions, one per line; "none" when it states none. *)
let count_text : Plan.count -> string = function
  | Count_exactly n -> Printf.sprintf "x%d" n
  | Count_gained n when n < 0 -> Printf.sprintf "used %d" (-n)
  | Count_gained n -> Printf.sprintf "gained %d" n
  | Count_at_least n -> Printf.sprintf "at least %d" n

let postconditions_text (plan : Plan.t) =
  let p = plan.postconditions in
  let list = String.concat ", " in
  List.concat
    [
      Option.fold ~none:[]
        ~some:(fun g -> [ "position " ^ Pose.grid_to_string g ])
        p.position;
      (match p.party with
      | Some (Party_in_order l) -> [ "party in order " ^ list l ]
      | Some (Party_includes { members; slots }) ->
          ("party includes " ^ list members)
          :: List.map
               (fun ({ slot; species } : Plan.slot) ->
                 Printf.sprintf "%s in slot %d" species slot)
               slots
      | None -> []);
      List.map
        (fun ({ bag_item; count } : Plan.bag_count) ->
          Printf.sprintf "item %s %s" bag_item (count_text count))
        p.items;
      Option.fold ~none:[] ~some:(fun c -> [ "coins " ^ count_text c ]) p.coins;
      Option.fold ~none:[]
        ~some:(function
          | Plan.Money_range { min; max } ->
              [ Printf.sprintf "money %d to %d" min max ]
          | Money_spent n -> [ Printf.sprintf "money spent %d" n ])
        p.money;
      (if p.flags = [] then [] else [ "flags " ^ list p.flags ]);
      List.map
        (fun ({ species; moves } : Plan.knows) ->
          Printf.sprintf "%s knows %s" species (list moves))
        p.knows;
      List.map
        (fun ({ species; min } : Plan.level) ->
          Printf.sprintf "%s at least Lv %d" species min)
        p.levels;
      Option.fold ~none:[] ~some:(fun m -> [ "marks " ^ list m ]) p.marks;
    ]
  |> function
  | [] -> "none"
  | lines -> String.concat "\n" lines

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
  | Ok plan -> postconditions_text plan
  | Error message -> message

let post = at ^ "metadata.postconditions."

let postcondition_cases : Table_test.case list =
  [
    {
      name =
        "mg-01 promises the members the plans use (Abra among them), 20 coins \
         gained and $4,100 spent";
      input = (fun () -> postconditions_text (load "mg-01.plan.json" mg));
      expectation =
        "party includes blastoise, pidgey, abra\n\
         coins gained 20\n\
         money spent 4100";
    };
    {
      name = "mg-05 promises MIMIEN, Pidgey and slots 1-3's marks";
      input = (fun () -> postconditions_text (load "mg-05.plan.json" mg));
      expectation =
        "party includes mr-mime, pidgey\nmarks held_item, none, held_item";
    };
    {
      name = "mg-03 promises MIMIEN for Abra, 2 Revives and an Escape Rope";
      input = (fun () -> postconditions_text (load "mg-03.plan.json" mg));
      expectation =
        "party includes blastoise, pidgey, mr-mime, farfetchd\n\
         item revive gained 2\n\
         item escape-rope gained 1\n\
         money spent 3550";
    };
    {
      name = "mg-04a promises Knock Off and one rope used";
      input = (fun () -> postconditions_text (load "mg-04a.plan.json" mg));
      expectation =
        "party includes blastoise, pidgey, mr-mime, farfetchd\n\
         item revive gained 0\n\
         item escape-rope used 1\n\
         money spent 0\n\
         farfetchd knows knock-off";
    };
    {
      name = "a grind round (mg-04b) promises what holds on any save";
      input = (fun () -> postconditions_text (load "mg-04b.plan.json" mg));
      expectation =
        "position IndigoPlateau_PokemonCenter_1F (13, 12) north\n\
         party includes blastoise, pidgey, mr-mime, farfetchd\n\
         money spent 0";
    };
    {
      name = "mg-04c promises the grind's moves";
      input = (fun () -> postconditions_text (load "mg-04c.plan.json" mg));
      expectation =
        "party includes blastoise, pidgey, mr-mime, farfetchd\n\
         money spent 0\n\
         farfetchd knows knock-off\n\
         mr-mime knows recycle\n\
         mr-mime at least Lv 33";
    };
    {
      name = "mg-06 promises MIMIEN in slot 1, where the duplication gives";
      input = (fun () -> postconditions_text (load "mg-06.plan.json" mg));
      expectation =
        "party includes pidgey\n\
         mr-mime in slot 1\n\
         item antidote gained 0\n\
         item retro-mail gained 1\n\
         money spent 400";
    };
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
      name = "mg-05a promises Blastoise's Leppa Berry and MIMIEN's mail";
      input = (fun () -> postconditions_text (load "mg-05a.plan.json" mg));
      expectation =
        "party includes pidgey\n\
         farfetchd in slot 1\n\
         blastoise in slot 2\n\
         mr-mime in slot 3\n\
         item antidote gained 2\n\
         item super-potion gained 3\n\
         item retro-mail used 1\n\
         money spent 2300\n\
         marks held_item, held_item, mail";
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
    case "mg-05 retries the battle's luck 3 times"
      (fun () -> string_of_int (load "mg-05.plan.json" mg).retries)
      "3";
    case "no retries field: none"
      (fun () -> retries_of {|{"phase": "testing"}|})
      "0";
    case "negative retries are refused"
      (fun () -> retries_of {|{"retries": -1}|})
      (at ^ "metadata.retries is -1, not 0 or more.");
  ]

let repeat_text (plan : Plan.t) =
  match plan.repeat with
  | None -> "no repeat"
  | Some { until; max_rounds } ->
      Printf.sprintf "at most %d rounds, until:\n%s" max_rounds
        (postconditions_text { plan with postconditions = until })

let repeat_of metadata =
  let text =
    edited {|"title": "Test",|}
      (Printf.sprintf {|"title": "Test", "metadata": %s,|} metadata)
  in
  match
    Plan_decode.decode ~source:"base.plan.json" (Yojson.Safe.from_string text)
  with
  | Ok plan -> repeat_text plan
  | Error message -> message

let repeat_cases : Table_test.case list =
  let case name input expectation : Table_test.case =
    { name; input; expectation }
  in
  [
    case "mg-04b repeats until MIMIEN is Lv 33 and knows Recycle"
      (fun () -> repeat_text (load "mg-04b.plan.json" mg))
      "at most 20 rounds, until:\nmr-mime knows recycle\nmr-mime at least Lv 33";
    case "mg-04b retries each round twice"
      (fun () -> string_of_int (load "mg-04b.plan.json" mg).retries)
      "2";
    case "no repeat field: none"
      (fun () -> repeat_of {|{"phase": "testing"}|})
      "no repeat";
    case "max_rounds below 1 is refused"
      (fun () -> repeat_of {|{"repeat": {"until": {}, "max_rounds": 0}}|})
      (at ^ "metadata.repeat.max_rounds is 0, not 1 or more.");
    case "until is required"
      (fun () -> repeat_of {|{"repeat": {"max_rounds": 3}}|})
      (at ^ "metadata.repeat.until is missing.");
    case "an unknown goal field is refused"
      (fun () ->
        repeat_of {|{"repeat": {"until": {"badges": 3}, "max_rounds": 3}}|})
      (at ^ "metadata.repeat.until.badges is not a known field.");
  ]

let () =
  Table_test.run "plan_decode"
    (real_plans @ inline_plans @ postcondition_cases @ retries_cases
   @ repeat_cases)
