open Grid_geometry
open Pokemon_rules.Pose

let with_facing text = function
  | Some direction -> text ^ " " ^ Direction.name direction
  | None -> text

let grid pose =
  let tiles = String.concat "|" (List.map Tile_pos.to_string pose.tiles) in
  let place = if tiles = "" then pose.map else pose.map ^ " " ^ tiles in
  with_facing place pose.facing

let observed observed =
  with_facing
    (observed.at_map ^ " " ^ Tile_pos.to_string observed.at_tile)
    observed.faces

let declared = function
  | Grid g -> grid g
  | Zone { place; _ } -> "zone " ^ place
