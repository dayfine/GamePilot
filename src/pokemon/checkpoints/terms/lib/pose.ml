open Grid_maps

type grid = {
  map : string;
  tiles : Tile_pos.t list;
  facing : Direction.t option;
}

type zone = { place : string; spot : string option; heading : int option }
type declared = Grid of grid | Zone of zone

(* A tile is kept as [[x, y]], a facing by its name; a facing the run cannot
   read back is unknown, as when the game could not tell. *)
let tile_to_json (t : Tile_pos.t) = `List [ `Int t.x; `Int t.y ]

let tile_of_json : Yojson.Safe.t -> (Tile_pos.t, string) result = function
  | `List [ `Int x; `Int y ] -> Ok { x; y }
  | _ -> Error "tile: not [x, y]"

let facing_to_json = function
  | Some d -> `String (Direction.name d)
  | None -> `Null

let facing_of_json = function
  | `String name -> Ok (Direction.of_name name)
  | _ -> Ok None

type observed = {
  at_map : string; [@key "map"]
  at_tile : Tile_pos.t;
      [@key "tile"] [@to_yojson tile_to_json] [@of_yojson tile_of_json]
  faces : Direction.t option;
      [@key "facing"] [@to_yojson facing_to_json] [@of_yojson facing_of_json]
}
[@@deriving yojson { strict = false }]

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
