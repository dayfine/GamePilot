(* Fragment calls expanded with a made-up table: a parameter of kind "shop"
   whose clerk the game looks up, ids from the call's, the call's why and
   skip_if, and the errors. *)

module T = Checkpoints_expand.Fragment_table

let table_json =
  {|{"format": "gamepilot-fragments/1", "game": "test", "fragments": {
      "buy_at": {"params": {"shop": "shop"}, "events": [
        {"id": "walk", "kind": "route", "args": {"target": {"place": "{shop.clerk}"}},
         "why": "to the clerk of {shop}"},
        {"id": "", "kind": "talk"}]}}}|}

let table =
  Result.get_ok (T.parse ~source:"f.json" (Yojson.Safe.from_string table_json))

let resolve ~kind value ~field =
  match (kind, value, field) with
  | "shop", "corner", None -> Ok "corner"
  | "shop", "corner", Some "clerk" -> Ok "corner_clerk"
  | "shop", _, Some f when f <> "clerk" -> Error ("a shop has no " ^ f)
  | _ -> Error ("no shop " ^ value)

let expanded =
  Expand_cases.expanded (Checkpoints_expand.Fragment_calls.expand table resolve)

let case = Expand_cases.case

let parse text () =
  match T.parse ~source:"f.json" (Yojson.Safe.from_string text) with
  | Ok t ->
      String.concat ", "
        (List.map (fun (f : T.fragment) -> f.name) (T.fragments t))
  | Error e -> e

let one_fragment events =
  Printf.sprintf
    {|{"format": "gamepilot-fragments/1", "game": "test", "fragments": {
        "f": {"params": {"a": "shop"}, "events": [%s]}}}|}
    events

let () =
  Table_test.run "fragment_calls"
    [
      case "a call: the fragment's events, filled in, ids from the call's"
        (expanded
           [
             {|{"id": "buy", "fragment": "buy_at", "args": {"shop": "corner"}, "why": "stock up", "skip_if": ["stocked"]}|};
           ])
        {|{"id":"buy.walk","kind":"route","args":{"target":{"place":"corner_clerk"}},"why":"to the clerk of corner","skip_if":["stocked"]}
{"id":"buy","kind":"talk","skip_if":["stocked"],"why":"stock up"}|};
      case "events that call no fragment are left as they are"
        (expanded [ {|{"id": "x", "kind": "talk"}|} ])
        {|{"id":"x","kind":"talk"}|};
      case "a misspelt fragment suggests the nearest"
        (expanded [ {|{"id": "x", "fragment": "buy_ta", "args": {}}|} ])
        "t: checkpoint.events[0]: no fragment \"buy_ta\"; did you mean buy_at?";
      case "args that are not the fragment's params"
        (expanded
           [ {|{"id": "x", "fragment": "buy_at", "args": {"town": "a"}}|} ])
        "t: checkpoint.events[0]: buy_at takes args shop, not town.";
      case "a field a call does not take"
        (expanded
           [
             {|{"id": "x", "fragment": "buy_at", "kind": "talk", "args": {"shop": "corner"}}|};
           ])
        "t: checkpoint.events[0]: kind is not a field a fragment call takes.";
      case "the game's error for an unknown key"
        (expanded
           [ {|{"id": "x", "fragment": "buy_at", "args": {"shop": "mall"}}|} ])
        "t: checkpoint.events[0]: no shop mall";
      case "a table's fragments" (parse table_json) "buy_at";
      case "a placeholder that names no parameter"
        (parse
           (one_fragment
              {|{"id": "", "kind": "route", "args": {"target": {"place": "{b.clerk}"}}}|}))
        "f.json: fragments.f.events[0].{b} names no parameter.";
      case "an event without an id"
        (parse (one_fragment {|{"kind": "talk"}|}))
        "f.json: fragments.f.events[0].id is missing.";
    ]
