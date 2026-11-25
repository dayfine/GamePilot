open Grid_maps

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

let declared_to_string = function
  | Grid grid -> grid_to_string grid
  | Zone { place; _ } -> "zone " ^ place

let observed_to_json p =
  `Assoc
    [
      ("map", `String p.at_map);
      ("tile", `List [ `Int p.at_tile.x; `Int p.at_tile.y ]);
      ( "facing",
        match p.faces with
        | Some d -> `String (Direction.name d)
        | None -> `Null );
    ]

let facing_of = function `String name -> Direction.of_name name | _ -> None

let observed_of_json = function
  | `Assoc f -> (
      match (List.assoc_opt "map" f, List.assoc_opt "tile" f) with
      | Some (`String at_map), Some (`List [ `Int x; `Int y ]) ->
          let faces = Option.bind (List.assoc_opt "facing" f) facing_of in
          Ok { at_map; at_tile = { x; y }; faces }
      | _ -> Error "not a map and a tile")
  | _ -> Error "not an object"
