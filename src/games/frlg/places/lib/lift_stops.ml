module L = Frlg_actions.Lift_ride

type stop = {
  lift : L.lift;
  floor : string;
  map : string;
  door : Checkpoints.Pose.grid;
}

let stop lift (exit : Checkpoints.Pose.grid) floor =
  let door = { exit with facing = Some Grid_maps.Direction.North } in
  { lift; floor; map = exit.map; door }

(* The menu's floors (EXIT left out) beside their exits. *)
let stops lift =
  List.filteri (fun i _ -> i < List.length (L.exits lift)) (L.menu lift)
  |> List.map2 (stop lift) (L.exits lift)

let all = stops L.Dept_store @ stops L.Rocket_hideout
let of_map map = List.find_opt (fun s -> s.map = map) all

let way_out lift =
  let floor =
    match lift with L.Dept_store -> "1F" | L.Rocket_hideout -> "B1F"
  in
  List.find (fun s -> s.lift = lift && s.floor = floor) all
