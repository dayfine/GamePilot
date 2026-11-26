open Grid_geometry

type grid = {
  map : string;
  tiles : Tile_pos.t list;
  facing : Direction.t option;
}

type zone = { place : string; spot : string option; heading : int option }
type place_class = Outdoors
type declared = Grid of grid | Zone of zone | Anywhere of place_class

type observed = {
  at_map : string;
  at_tile : Tile_pos.t;
  faces : Direction.t option;
}

let grid_matches pose observed =
  let tile_ok =
    pose.tiles = [] || List.exists (Tile_pos.equal observed.at_tile) pose.tiles
  in
  let facing_ok =
    match (pose.facing, observed.faces) with
    | Some want, Some seen -> want = seen
    | _ -> true
  in
  String.equal pose.map observed.at_map && tile_ok && facing_ok

let with_facing text = function
  | Some direction -> text ^ " " ^ Direction.name direction
  | None -> text

let grid_to_string pose =
  let tiles = String.concat "|" (List.map Tile_pos.to_string pose.tiles) in
  let place = if tiles = "" then pose.map else pose.map ^ " " ^ tiles in
  with_facing place pose.facing

let observed_to_string observed =
  with_facing
    (observed.at_map ^ " " ^ Tile_pos.to_string observed.at_tile)
    observed.faces

let place_class_name = function Outdoors -> "outdoors"
let place_class_of_name = function "outdoors" -> Some Outdoors | _ -> None

let place_class_text = function
  | Outdoors -> "anywhere outdoors where Fly works"

let to_string = function
  | Grid g -> grid_to_string g
  | Zone { place; _ } -> "zone " ^ place
  | Anywhere c -> "anywhere " ^ place_class_name c
