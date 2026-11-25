module L = Frlg_actions.Lift_ride
module R = Checkpoints_expand.Place_routes

type stop = {
  lift : L.lift;
  floor : string;
  map : string;
  door : R.spot;
  exit : R.spot;
}

let stop lift (exit : Checkpoints_plan.Pose.grid) floor =
  let tile = List.hd exit.tiles in
  {
    lift;
    floor;
    map = exit.map;
    door = { map = exit.map; tile; facing = Some Grid_maps.Direction.North };
    exit = { map = exit.map; tile; facing = exit.facing };
  }

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

let lift_floor from to_ =
  [
    ("kind", `String "game_action");
    ("action", `String "lift_floor");
    ("args", `Assoc [ ("from", `String from.floor); ("to", `String to_.floor) ]);
  ]

let lift_ride from to_ : R.ride option =
  let why = Printf.sprintf "ride the lift from %s to %s" from.floor to_.floor in
  if from.floor = to_.floor then None
  else
    Some
      {
        start = from.door;
        event = lift_floor from to_;
        suffix = "lift";
        why;
        arrival = to_.exit;
      }

let ride ~(at : R.spot) (target : R.spot) =
  let off s = way_out s.lift in
  match (of_map at.map, of_map target.map) with
  | None, None -> Ok None
  | Some from, None -> Ok (lift_ride from (off from))
  | None, Some to_ -> Ok (lift_ride (off to_) to_)
  | Some from, Some to_ when from.lift = to_.lift -> Ok (lift_ride from to_)
  | Some from, Some to_ ->
      Error
        (Printf.sprintf "the walk from %s to %s crosses two lifts." from.map
           to_.map)
