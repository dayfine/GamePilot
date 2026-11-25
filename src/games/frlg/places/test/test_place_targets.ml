(* Place routes expanded at load: the lift case on small plans, and mg-01,
   mg-06, su-01 and tt-01 against their hand-written plans from before places
   (before/): the same events, walks, rides and end poses, only the ids and
   whys differ. *)

let table = Result.get_ok (Frlg_places.Place_table.load ())

let plan_text ~start events =
  Printf.sprintf
    {|{"format": "gamepilot-checkpoint/1", "game": "frlg",
       "checkpoint": {"id": "t", "title": "t", "start": %s, "events": [%s]},
       "execution": {}}|}
    start
    (String.concat ", " events)

let route id place =
  Printf.sprintf
    {|{"id": "%s", "kind": "route", "action": "run", "args": {"target": {"place": "%s"}}}|}
    id place

let at_1f =
  {|{"map": "CeladonCity_DepartmentStore_1F", "tiles": [[6, 2]], "facing": "south"}|}

let outside = {|{"map": "CeladonCity", "tiles": [[48, 12]], "facing": "south"}|}

let event_line (e : Checkpoints.Plan.event) =
  match e.kind with
  | Route r -> e.id ^ " to " ^ Checkpoints.Pose.grid_to_string r.target
  | Game_action args ->
      Printf.sprintf "%s %s %s" e.id
        (Option.value ~default:"" e.action)
        (Yojson.Safe.to_string (`Assoc args))
  | _ -> e.id

let expanded ~start events () =
  let json = Yojson.Safe.from_string (plan_text ~start events) in
  match Frlg_checkpoints.Plan_file.decode ~source:"t" json with
  | Ok p -> String.concat "; " (List.map event_line p.checkpoint.events)
  | Error e -> e

let without_names (e : Checkpoints.Plan.event) = { e with id = ""; why = "" }

let first_difference before after =
  let rec go i = function
    | [], [] -> "the same events"
    | (b : Checkpoints.Plan.event) :: bs, (a : Checkpoints.Plan.event) :: as_ ->
        if without_names b = without_names a then go (i + 1) (bs, as_)
        else Printf.sprintf "event %d differs: %s, now %s" i b.id a.id
    | _ ->
        Printf.sprintf "%d events before, %d now" (List.length before)
          (List.length after)
  in
  go 0 (before, after)

let same_as_before id () =
  let before =
    Result.get_ok (Checkpoints.Plan_decode.load ("before/" ^ id ^ ".plan.json"))
  in
  let after =
    Result.get_ok (Frlg_checkpoints.Plan_file.load (id ^ ".plan.json"))
  in
  let rest (p : Checkpoints.Plan.t) =
    { p with checkpoint = { p.checkpoint with events = [] } }
  in
  if rest before <> rest after then "the plan around the events differs"
  else first_difference before.checkpoint.events after.checkpoint.events

let ids id () =
  let p = Result.get_ok (Frlg_checkpoints.Plan_file.load (id ^ ".plan.json")) in
  String.concat " "
    (List.map (fun (e : Checkpoints.Plan.event) -> e.id) p.checkpoint.events)

let case name input expectation = { Table_test.name; input; expectation }

let () =
  ignore table;
  Table_test.run "place_targets"
    [
      case "a place on the floor the player is on: one route"
        (expanded ~start:at_1f [ route "save" "dept_store_1f_save" ])
        "save to CeladonCity_DepartmentStore_1F (6, 2) south";
      case "a place on another floor: to the lift, the ride, the walk"
        (expanded ~start:at_1f [ route "clerk" "dept_store_4f_clerk" ])
        "clerk to CeladonCity_DepartmentStore_1F (6, 2) north; clerk.lift \
         lift_floor {\"from\":\"1F\",\"to\":\"4F\"}; clerk.walk to \
         CeladonCity_DepartmentStore_4F (3, 11) south";
      case
        "from outside the store to 4F: the route takes the player to 1F's lift"
        (expanded ~start:outside [ route "clerk" "dept_store_4f_clerk" ])
        "clerk to CeladonCity_DepartmentStore_1F (6, 2) north; clerk.lift \
         lift_floor {\"from\":\"1F\",\"to\":\"4F\"}; clerk.walk to \
         CeladonCity_DepartmentStore_4F (3, 11) south";
      case "from 4F to outside: down to 1F first"
        (expanded ~start:at_1f
           [
             route "clerk" "dept_store_4f_clerk";
             route "out" "dept_store_west_door_outside";
           ])
        "clerk to CeladonCity_DepartmentStore_1F (6, 2) north; clerk.lift \
         lift_floor {\"from\":\"1F\",\"to\":\"4F\"}; clerk.walk to \
         CeladonCity_DepartmentStore_4F (3, 11) south; out to \
         CeladonCity_DepartmentStore_4F (6, 2) north; out.lift lift_floor \
         {\"from\":\"4F\",\"to\":\"1F\"}; out.walk to CeladonCity (11, 15) \
         south";
      case "a ride that lets the player out on the place: no walk"
        (expanded ~start:at_1f
           [
             route "clerk" "dept_store_4f_clerk";
             route "down" "dept_store_1f_save";
           ])
        "clerk to CeladonCity_DepartmentStore_1F (6, 2) north; clerk.lift \
         lift_floor {\"from\":\"1F\",\"to\":\"4F\"}; clerk.walk to \
         CeladonCity_DepartmentStore_4F (3, 11) south; down to \
         CeladonCity_DepartmentStore_4F (6, 2) north; down.lift lift_floor \
         {\"from\":\"4F\",\"to\":\"1F\"}";
      case "an unknown place names the event and the nearest place"
        (expanded ~start:at_1f [ route "clerk" "dept_store_4f_clerc" ])
        "t: checkpoint.events[0]: no place \"dept_store_4f_clerc\"; did you \
         mean dept_store_4f_clerk?";
      case "a place route with nowhere known to start from"
        (expanded ~start:{|{"map": "CeladonCity"}|}
           [ route "clerk" "dept_store_4f_clerk" ])
        "t: checkpoint.events[0]: where the player stands before it is not \
         known: give the checkpoint a start, or the event before it a one-tile \
         declared_after.";
      case "mg-01 as before" (same_as_before "mg-01") "the same events";
      case "mg-06 as before" (same_as_before "mg-06") "the same events";
      case "su-01 as before" (same_as_before "su-01") "the same events";
      case "tt-01 as before" (same_as_before "tt-01") "the same events";
      case "mg-01's ids" (ids "mg-01")
        "fly_celadon to_coin_case_man talk_coin_case_man clear_coin_case_text \
         to_4f_clerk to_4f_clerk.lift to_4f_clerk.walk buy_retro_mail \
         to_coins_clerk to_coins_clerk.lift to_coins_clerk.walk buy_200_coins \
         to_prize_clerk redeem_abra exit_prize_room";
    ]
