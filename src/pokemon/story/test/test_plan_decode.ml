(* Plan_decode reads every real plan (PokemonSimulation's FireRed plans and the
   Mail Glitch program's), types each built-in kind's args, and rejects a broken
   plan naming the field. *)

open Story

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
  {|{"format": "pokesim-authored-checkpoint/1", "game": "test", "execution": {"menu": "full"},
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
    Case_table.name;
    input = (fun () -> decoded (edited find replacement));
    expectation;
  }

let at = "base.plan.json: checkpoint."

let real_plans : Case_table.case list =
  [
    {
      name = "every PokemonSimulation FireRed plan";
      input = (fun () -> load_all (Plan_files.plans_in authored));
      expectation = "all decode";
    };
    {
      name = "every Mail Glitch plan";
      input = (fun () -> load_all (Plan_files.plans_in mg));
      expectation = "all decode";
    };
    {
      name = "mg-01 outline";
      input = (fun () -> outline "mg-01.plan.json" mg);
      expectation =
        "frlg mg-01 from CeladonCity (48, 12) south: 6 game_action, 7 route, 1 \
         talk, 1 scene";
    };
    {
      name = "mg-02 outline";
      input = (fun () -> outline "mg-02.plan.json" mg);
      expectation =
        "frlg mg-02 from CeladonCity (39, 21) south: 7 route, 5 game_action, 1 \
         talk, 1 scene";
    };
    {
      name = "mg-03 outline";
      input = (fun () -> outline "mg-03.plan.json" mg);
      expectation =
        "frlg mg-03 from VermilionCity (19, 18) south: 5 game_action, 5 route, \
         1 heal";
    };
    {
      name = "mg-04 outline";
      input = (fun () -> outline "mg-04.plan.json" mg);
      expectation =
        "frlg mg-04 from LavenderTown_PokemonCenter_1F (7, 4) north: 3 route, \
         5 game_action";
    };
    {
      name = "mg-05 outline";
      input = (fun () -> outline "mg-05.plan.json" mg);
      expectation =
        "frlg mg-05 from LavenderTown (18, 7) south: 3 route, 10 game_action";
    };
    {
      name = "a plan with no start (new game)";
      input = (fun () -> outline "frlg-00.01.plan.json" authored);
      expectation = "frlg 00.01 from (no start): 1 new_game, 1 options";
    };
    {
      name = "a route's typed target";
      input = (fun () -> event "mg-01.plan.json" mg "to_coin_case_man");
      expectation =
        "to_coin_case_man: [run] route to CeladonCity_Restaurant (2, 2) west";
    };
    {
      name = "a game action keeps its args as JSON, and its declared_after";
      input = (fun () -> event "mg-01.plan.json" mg "lift_1f_to_4f");
      expectation =
        {|lift_1f_to_4f: [lift_floor] game_action {"from":"1F","to":"4F"} => CeladonCity_DepartmentStore_4F (6, 2) south|};
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

let inline_plans : Case_table.case list =
  [
    {
      name = "built-in args typed, fallbacks filled in";
      input = (fun () -> decoded base);
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
      ( {|"format": "pokesim-authored-checkpoint/1"|},
        {|"format": "pokesim-story-plan/1"|} )
      {|base.plan.json: format is "pokesim-story-plan/1", not pokesim-authored-checkpoint/1.|};
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
      | Some (Party_includes l) -> [ "party includes " ^ list l ]
      | None -> []);
      List.map
        (fun ({ item; quantity } : Plan.item) ->
          Printf.sprintf "item %s x%d" item quantity)
        p.items;
      Option.fold ~none:[]
        ~some:(fun c -> [ Printf.sprintf "coins %d" c ])
        p.coins;
      Option.fold ~none:[]
        ~some:(fun ({ min; max } : Plan.money) ->
          [ Printf.sprintf "money %d to %d" min max ])
        p.money;
      (if p.flags = [] then [] else [ "flags " ^ list p.flags ]);
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

let postcondition_cases : Case_table.case list =
  [
    {
      name = "mg-01 promises Abra, 20 coins and $25,014";
      input = (fun () -> postconditions_text (load "mg-01.plan.json" mg));
      expectation =
        "party in order blastoise, rattata, oddish, pidgey, abra\n\
         coins 20\n\
         money 25014 to 25014";
    };
    {
      name = "a plan that states none";
      input = (fun () -> postconditions_text (load "mg-03.plan.json" mg));
      expectation = "none";
    };
    {
      name = "every postcondition, PokemonSimulation's and ours";
      input =
        (fun () ->
          with_postconditions
            {|{"position": {"map": "Town", "tiles": [[3, 4]]}, "party_includes": ["abra", "abra"],
               "items": [{"item": "retro-mail", "quantity": 2}], "coins": 20,
               "money": {"min": 100, "max": 200}, "flags": ["got_coin_case"]}|});
      expectation =
        "position Town (3, 4)\n\
         party includes abra, abra\n\
         item retro-mail x2\n\
         coins 20\n\
         money 100 to 200\n\
         flags got_coin_case";
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
      name = "money min above max";
      input =
        (fun () -> with_postconditions {|{"money": {"min": 5, "max": 4}}|});
      expectation = post ^ "money.min 5 is above max 4.";
    };
    {
      name = "an unknown postcondition";
      input = (fun () -> with_postconditions {|{"badges": 3}|});
      expectation = post ^ "badges is not a known field.";
    };
  ]

let () =
  Case_table.run "plan_decode" (real_plans @ inline_plans @ postcondition_cases)
