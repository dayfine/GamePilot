open Grid_geometry

type grid = {
  map : string;
  tiles : Tile_pos.t list;
  facing : Direction.t option;
}

type zone = { place : string; spot : string option; heading : int option }
type declared = Grid of grid | Zone of zone

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
