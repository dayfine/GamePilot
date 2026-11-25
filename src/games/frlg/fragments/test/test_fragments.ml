(* The fragments table and fragment calls expanded at load: small plans, the
   errors, and mg-03 and mg-04a against their hand-written plans from before
   fragments (before/): the same events, only the ids and whys differ. *)

let plan_text events =
  Printf.sprintf
    {|{"format": "gamepilot-checkpoint/1", "game": "frlg",
       "checkpoint": {"id": "t", "title": "t",
         "start": {"map": "LavenderTown", "tiles": [[6, 6]], "facing": "south"},
         "events": [%s]},
       "execution": {}}|}
    (String.concat ", " events)

let event_line (e : Checkpoints.Plan.event) =
  let what =
    match e.kind with
    | Route r -> "to " ^ Checkpoints.Pose.grid_to_string r.target
    | Heal -> "heal"
    | _ -> "other"
  in
  Printf.sprintf "%s %s (%s)%s" e.id what e.why
    (match e.skip_if with [] -> "" | l -> " skip if " ^ String.concat "," l)

let expanded events () =
  let json = Yojson.Safe.from_string (plan_text events) in
  match Frlg_checkpoints.Plan_file.decode ~source:"t" json with
  | Ok p -> String.concat "; " (List.map event_line p.checkpoint.events)
  | Error e -> e

let parse text () =
  match
    Frlg_fragments.Fragment_table.parse ~source:"f.json"
      (Yojson.Safe.from_string text)
  with
  | Ok t ->
      String.concat ", "
        (List.map
           (fun (f : Frlg_fragments.Fragment_table.fragment) -> f.name)
           (Frlg_fragments.Fragment_table.fragments t))
  | Error e -> e

let without_names (e : Checkpoints.Plan.event) = { e with id = ""; why = "" }

let first_difference before after =
  let rec go i = function
    | [], [] -> "the same events"
    | (b : Checkpoints.Plan.event) :: bs, (a : Checkpoints.Plan.event) :: rest
      ->
        if without_names b = without_names a then go (i + 1) (bs, rest)
        else Printf.sprintf "event %d differs: %s, now %s" i b.id a.id
    | _ ->
        Printf.sprintf "%d events before, %d now" (List.length before)
          (List.length after)
  in
  go 0 (before, after)

let same_as_before id () =
  let load = Frlg_checkpoints.Plan_file.load in
  let before =
    Result.get_ok (Checkpoints.Plan_decode.load ("before/" ^ id ^ ".plan.json"))
  in
  let after = Result.get_ok (load (id ^ ".plan.json")) in
  let rest (p : Checkpoints.Plan.t) =
    { p with checkpoint = { p.checkpoint with events = [] } }
  in
  if rest before <> rest after then "the plan around the events differs"
  else first_difference before.checkpoint.events after.checkpoint.events

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "fragments"
    [
      case "the table: go_to and heal_at"
        (fun () ->
          match Frlg_fragments.Fragment_table.load () with
          | Ok t ->
              String.concat ", "
                (List.map
                   (fun (f : Frlg_fragments.Fragment_table.fragment) ->
                     f.name ^ "(" ^ String.concat ", " f.params ^ ")")
                   (Frlg_fragments.Fragment_table.fragments t))
          | Error e -> e)
        "go_to(place), heal_at(town)";
      case "go_to: one route to the place, the call's id and why"
        (expanded
           [
             {|{"id": "mart", "fragment": "go_to", "args": {"place": "lavender_mart_clerk"}, "why": "shop"}|};
           ])
        "mart to LavenderTown_Mart (4, 3) west (shop)";
      case "heal_at: the walk to the nurse, then the heal under the call's id"
        (expanded
           [
             {|{"id": "heal", "fragment": "heal_at", "args": {"town": "lavendertown"}, "why": "full HP", "skip_if": ["fresh"]}|};
           ])
        "heal.walk to LavenderTown_PokemonCenter_1F (7, 4) north (to the \
         Pokemon Center nurse, place lavendertown_nurse) skip if fresh; heal \
         heal (full HP) skip if fresh";
      case "a misspelt fragment suggests the nearest"
        (expanded [ {|{"id": "x", "fragment": "heel_at", "args": {}}|} ])
        "t: checkpoint.events[0]: no fragment \"heel_at\"; did you mean \
         heal_at?";
      case "args that are not the fragment's params"
        (expanded
           [ {|{"id": "x", "fragment": "go_to", "args": {"town": "a"}}|} ])
        "t: checkpoint.events[0]: go_to takes args place, not town.";
      case "a field a call does not take"
        (expanded
           [
             {|{"id": "x", "fragment": "go_to", "kind": "route", "args": {"place": "a"}}|};
           ])
        "t: checkpoint.events[0]: kind is not a field a fragment call takes.";
      case "a town with no nurse place: the place's error"
        (expanded
           [
             {|{"id": "x", "fragment": "heal_at", "args": {"town": "pallet"}}|};
           ])
        "t: checkpoint.events[0]: no place \"pallet_nurse\"";
      case "a template naming a parameter it does not declare"
        (parse
           {|{"format": "gamepilot-fragments/1", "game": "frlg", "fragments": {
               "f": {"params": ["a"], "events": [{"id": "", "kind": "route",
                     "args": {"target": {"place": "{b}"}}}]}}}|})
        "f.json: fragments.f.events[0].\"{b}\" names a parameter that is not \
         in params.";
      case "mg-03 as before" (same_as_before "mg-03") "the same events";
      case "mg-04a as before" (same_as_before "mg-04a") "the same events";
    ]
