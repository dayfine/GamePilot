(* Every plan decode error as the reader sees it, for the golden test
   (plan_errors.golden): one broken inline plan per case, its message printed
   under the case's name. The envelope, the events, the engine's story actions,
   each Pokémon action's args, the poses and the postconditions, and the plans
   with several bad fields (which one is named first). A change that keeps
   plan_errors.golden as it is reports every broken plan the same way. *)

open Pokemon_engine

let start = {|{"map": "Town", "tiles": [[1, 2]], "facing": "south"}|}

(* A plan around [events] (JSON objects), with [checkpoint] fields added to
   the checkpoint and [envelope] fields to the plan. *)
let plan ?(envelope = {|"execution": {}|}) ?(checkpoint = "") events =
  Printf.sprintf
    {|{"format": "gamepilot-checkpoint/1", "game": "test", %s,
       "checkpoint": {"id": "cp", "title": "Test", "start": %s%s,
         "events": [%s]}}|}
    envelope start checkpoint
    (String.concat ", " events)

let event ?(extra = "") kind args =
  Printf.sprintf {|{"id": "e", "kind": "%s", "args": %s%s}|} kind args extra

(* A plan whose only event is a [kind] with [args]. *)
let one kind args = plan [ event kind args ]

(* A plan promising [json] as its postconditions. *)
let promising json =
  plan
    ~checkpoint:
      (Printf.sprintf
         {|, "metadata": {"phase": "testing", "postconditions": %s}|} json)
    [ event "talk" "{}" ]

let envelope_cases =
  [
    ("not an object", "[]");
    ("a wrong format", {|{"format": "pokesim-story-plan/1"}|});
    ("no execution", plan ~envelope:{|"metadata": {}|} []);
    ("an unknown envelope field", plan ~envelope:{|"execution": {}, "x": 1|} []);
    ("no checkpoint", {|{"format": "gamepilot-checkpoint/1", "game": "t"}|});
    ("an unknown checkpoint field", plan ~checkpoint:{|, "x": 1|} []);
    ( "an empty checkpoint id",
      {|{"format": "gamepilot-checkpoint/1", "game": "t", "execution": {}, "checkpoint": {"id": "", "title": "T", "events": []}}|}
    );
    ( "no events",
      {|{"format": "gamepilot-checkpoint/1", "game": "t", "execution": {}, "checkpoint": {"id": "cp", "title": "T"}}|}
    );
    ("events not a list", plan ~checkpoint:{|, "events": 3|} []);
  ]

let event_cases =
  [
    ("an unknown event field", plan [ {|{"id": "e", "kind": "talk", "x": 1}|} ]);
    ("an event without an id", plan [ {|{"kind": "talk"}|} ]);
    ("an empty event id", plan [ {|{"id": "", "kind": "talk"}|} ]);
    ("an event without a kind", plan [ {|{"id": "e"}|} ]);
    ("an unknown kind", one "dance" "{}");
    ("a repeated event id", plan [ event "talk" "{}"; event "scene" "{}" ]);
    ("args not an object", one "talk" "[]");
    ( "skip_if not a list",
      plan [ event ~extra:{|, "skip_if": "met"|} "talk" "{}" ] );
    ( "once_per_save not true or false",
      plan [ event ~extra:{|, "once_per_save": 1|} "talk" "{}" ] );
    ("a game_action without its action", one "game_action" {|{"map": "Mart"}|});
    ( "a declared_after with a map and a place",
      plan
        [
          event ~extra:{|, "declared_after": {"map": "T", "place": "P"}|} "talk"
            "{}";
        ] );
    ( "a declared_after tile not a pair",
      plan
        [
          event ~extra:{|, "declared_after": {"map": "T", "tiles": [[1]]}|}
            "talk" "{}";
        ] );
  ]

let story_cases =
  [
    ("talk with an arg", one "talk" {|{"who": "nurse"}|});
    ("scene with an arg", one "scene" {|{"long": true}|});
    ("save with an arg", one "save" {|{"slot": 1}|});
    ("answer with an unknown arg", one "answer" {|{"yes": true, "loud": 1}|});
    ("answer not true or false", one "answer" {|{"yes": "no"}|});
  ]

let target = {|"target": {"map": "Town", "tiles": [[4, 0]], "facing": "north"}|}

let pokemon_action_cases =
  [
    ("new_game with an arg", one "new_game" {|{"name": "RED"}|});
    ("game_settings with an arg", one "game_settings" {|{"fast": true}|});
    ("heal with an arg", one "heal" {|{"where": "center"}|});
    ("route without a target", one "route" "{}");
    ( "route with an unknown arg",
      one "route" ("{" ^ target ^ {|, "run": true}|}) );
    ( "route fight_wild not true or false",
      one "route" ("{" ^ target ^ {|, "fight_wild": 1}|}) );
    ( "route target with an unknown field",
      one "route" {|{"target": {"map": "T", "spot": "x"}}|} );
    ( "route target without a map",
      one "route" {|{"target": {"tiles": [[4, 0]]}}|} );
    ( "route target tiles not a list",
      one "route" {|{"target": {"map": "T", "tiles": 4}}|} );
    ( "route target tile not a pair",
      one "route" {|{"target": {"map": "T", "tiles": [[4]]}}|} );
    ( "route target facing not a direction",
      one "route" {|{"target": {"map": "T", "facing": "up"}}|} );
    ( "ready with fight_wild",
      one "ready" ("{" ^ target ^ {|, "fight_wild": true}|}) );
    ("ready without a target", one "ready" "{}");
    ("legs without legs", one "legs" "{}");
    ("legs not a list", one "legs" {|{"legs": {}}|});
    ("a leg without tiles", one "legs" {|{"legs": [{"direction": "east"}]}|});
    ( "a leg with an unknown field",
      one "legs" {|{"legs": [{"direction": "east", "tiles": 1, "run": 1}]}|} );
    ( "a leg direction not a direction",
      one "legs" {|{"legs": [{"direction": "up", "tiles": 1}]}|} );
    ("step without a direction", one "step" "{}");
    ("step direction not a direction", one "step" {|{"direction": "up"}|});
    ("battle may_lose not true or false", one "battle" {|{"may_lose": "yes"}|});
    ("battle with an unknown arg", one "battle" {|{"flee": true}|});
    ("train without battles", one "train" "{}");
    ("train battles not a number", one "train" {|{"battles": "3"}|});
    ("shop without items", one "shop" "{}");
    ( "a shop item without a quantity",
      one "shop" {|{"items": [{"item": "potion"}]}|} );
    ( "a shop item with an unknown field",
      one "shop" {|{"items": [{"item": "potion", "quantity": 1, "price": 3}]}|}
    );
  ]

let postcondition_cases =
  [
    ("an unknown postcondition", promising {|{"badges": 3}|});
    ("postconditions not an object", promising "[]");
    ("a position with a place", promising {|{"position": {"place": "Plaza"}}|});
    ("a position without a map", promising {|{"position": {"tiles": [[1, 2]]}}|});
    ( "a position with an unknown field",
      promising {|{"position": {"map": "T", "heading": 9}}|} );
    ( "party and party_includes",
      promising {|{"party": ["abra"], "party_includes": ["abra"]}|} );
    ( "party_slots with party",
      promising
        {|{"party": ["abra"], "party_slots": [{"slot": 1, "species": "abra"}]}|}
    );
    ( "a party slot past six",
      promising {|{"party_slots": [{"slot": 7, "species": "abra"}]}|} );
    ( "a party slot with an unknown field",
      promising
        {|{"party_slots": [{"slot": 1, "species": "abra", "level": 5}]}|} );
    ("party not a list of names", promising {|{"party": [1]}|});
    ("an item with no count", promising {|{"items": [{"item": "potion"}]}|});
    ( "an item with two counts",
      promising {|{"items": [{"item": "potion", "quantity": 3, "gained": 1}]}|}
    );
    ( "an item with an unknown field",
      promising {|{"items": [{"item": "potion", "quantity": 1, "x": 1}]}|} );
    ("coins not a number or an object", promising {|{"coins": "20"}|});
    ("coins with no count", promising {|{"coins": {}}|});
    ( "coins with an unknown field",
      promising {|{"coins": {"gained": 1, "x": 1}}|} );
    ("money with neither a range nor spent", promising {|{"money": {}}|});
    ( "money spent and a range",
      promising {|{"money": {"spent": 1, "min": 1, "max": 2}}|} );
    ("money min above max", promising {|{"money": {"min": 5, "max": 4}}|});
    ( "money with an unknown field",
      promising {|{"money": {"spent": 1, "x": 1}}|} );
    ("flags not a list", promising {|{"flags": "met"}|});
    ("knows without moves", promising {|{"knows": [{"species": "abra"}]}|});
    ("a level without its min", promising {|{"levels": [{"species": "abra"}]}|});
    ("a mark no party shows", promising {|{"marks": ["berry"]}|});
  ]

(* Several bad fields at once: which the error names pins the order the
   readers run in. *)
let several_cases =
  [
    ( "bad items, coins and money",
      promising {|{"items": [{"item": "p"}], "coins": {}, "money": {}}|} );
    ("bad coins and money", promising {|{"coins": {}, "money": {}}|});
    ( "bad items and coins",
      promising {|{"items": [{"item": "p"}], "coins": {}}|} );
    ( "a bad position and marks",
      promising {|{"position": {"x": 1}, "marks": ["berry"]}|} );
    ("a bad party and levels", promising {|{"party": [1], "levels": [{}]}|});
    ( "an unknown field and a bad money",
      promising {|{"badges": 1, "money": {}}|} );
    ( "a bad event and bad postconditions",
      plan ~checkpoint:{|, "metadata": {"postconditions": {"money": {}}}|}
        [ event "dance" "{}" ] );
    ( "a bad kind and a bad declared_after",
      plan [ event ~extra:{|, "declared_after": {}|} "dance" "{}" ] );
    ( "a bad arg and a bad skip_if",
      plan [ event ~extra:{|, "skip_if": 1|} "step" {|{"direction": "up"}|} ] );
  ]

let repeat_cases =
  [
    ( "a repeat without until",
      plan ~checkpoint:{|, "metadata": {"repeat": {"max_rounds": 3}}|} [] );
    ( "a repeat below one round",
      plan
        ~checkpoint:{|, "metadata": {"repeat": {"until": {}, "max_rounds": 0}}|}
        [] );
    ( "a repeat goal with an unknown field",
      plan
        ~checkpoint:
          {|, "metadata": {"repeat": {"until": {"badges": 3}, "max_rounds": 3}}|}
        [] );
    ("negative retries", plan ~checkpoint:{|, "metadata": {"retries": -1}|} []);
  ]

let message text =
  match Yojson.Safe.from_string text with
  | exception Yojson.Json_error e -> "not JSON: " ^ e
  | json -> (
      match Plan_decode.decode ~source:"p.plan.json" json with
      | Ok _ -> "decodes"
      | Error message -> message)

let print_section (title, cases) =
  Printf.printf "== %s\n" title;
  List.iter
    (fun (name, text) -> Printf.printf "%s\n  %s\n" name (message text))
    cases

let () =
  List.iter print_section
    [
      ("the envelope", envelope_cases);
      ("events", event_cases);
      ("the engine's story actions", story_cases);
      ("the Pokémon actions", pokemon_action_cases);
      ("postconditions", postcondition_cases);
      ("several bad fields", several_cases);
      ("repeats and retries", repeat_cases);
    ]
