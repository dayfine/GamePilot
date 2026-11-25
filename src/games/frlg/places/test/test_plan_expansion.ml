(* FireRed's tables in the plan expansion: a place on another floor of the
   Dept. Store is reached by the lift, from inside the store or outside it;
   heal_at looks its town's nurse up in the towns. *)

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

let expanded ~start events () =
  match
    Frlg_checkpoints.Plan_file.decode ~source:"t"
      (Yojson.Safe.from_string (plan_text ~start events))
  with
  | Ok p -> String.concat "\n" (List.map Plan_text.event p.checkpoint.events)
  | Error e -> e

let up_to_4f =
  "clerk: [run] route to CeladonCity_DepartmentStore_1F (6, 2) north\n\
   clerk.lift: [lift_floor] game_action {\"from\":\"1F\",\"to\":\"4F\"} => \
   CeladonCity_DepartmentStore_4F (6, 2) south\n\
   clerk.walk: [run] route to CeladonCity_DepartmentStore_4F (3, 11) south"

let heal_at town =
  Printf.sprintf
    {|{"id": "heal", "fragment": "heal_at", "args": {"town": "%s"}, "why": "full HP"}|}
    town

let lavender = {|{"map": "LavenderTown", "tiles": [[6, 6]], "facing": "south"}|}
let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "plan_expansion"
    [
      case "a place on the floor the player is on: one route"
        (expanded ~start:at_1f [ route "save" "celadon_dept_store_1f_save" ])
        "save: [run] route to CeladonCity_DepartmentStore_1F (6, 2) south";
      case "a place on another floor: to the lift, the ride, the walk"
        (expanded ~start:at_1f [ route "clerk" "celadon_dept_store_4f_clerk" ])
        up_to_4f;
      case "from outside the store: the same, from 1F's lift"
        (expanded ~start:outside
           [ route "clerk" "celadon_dept_store_4f_clerk" ])
        up_to_4f;
      case "from 4F to outside: down to 1F first"
        (expanded ~start:at_1f
           [
             route "clerk" "celadon_dept_store_4f_clerk";
             route "out" "celadon_dept_store_west_door_outside";
           ])
        (up_to_4f
       ^ "\n\
          out: [run] route to CeladonCity_DepartmentStore_4F (6, 2) north\n\
          out.lift: [lift_floor] game_action {\"from\":\"4F\",\"to\":\"1F\"} \
          => CeladonCity_DepartmentStore_1F (6, 2) south\n\
          out.walk: [run] route to CeladonCity (11, 15) south");
      case "a ride that lets the player out on the place: no walk"
        (expanded ~start:at_1f
           [
             route "clerk" "celadon_dept_store_4f_clerk";
             route "down" "celadon_dept_store_1f_save";
           ])
        (up_to_4f
       ^ "\n\
          down: [run] route to CeladonCity_DepartmentStore_4F (6, 2) north\n\
          down.lift: [lift_floor] game_action {\"from\":\"4F\",\"to\":\"1F\"} \
          => CeladonCity_DepartmentStore_1F (6, 2) south");
      case "heal_at: the walk to the town's nurse, then the heal"
        (expanded ~start:lavender [ heal_at "lavender" ])
        "heal.walk: [run] route to LavenderTown_PokemonCenter_1F (7, 4) north\n\
         heal: heal";
      case "heal_at an unknown town suggests the nearest"
        (expanded ~start:lavender [ heal_at "lavendar" ])
        "t: checkpoint.events[0]: no town \"lavendar\"; did you mean lavender?";
    ]
