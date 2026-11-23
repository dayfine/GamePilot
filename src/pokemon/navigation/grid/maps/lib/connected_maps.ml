open Map_features

type place = { map : int; tile : Tile_pos.t }

let compare_place a b =
  match Int.compare a.map b.map with
  | 0 -> Tile_pos.compare a.tile b.tile
  | c -> c

type t = Map_data.t array

let create maps = Array.of_list maps
let size = Array.length

let map world index =
  if index < 0 || index >= Array.length world then
    invalid_arg
      (Printf.sprintf "Connected_maps.map: index %d is past the %d maps" index
         (Array.length world));
  world.(index)

let find world name =
  let rec from index =
    if index >= Array.length world then None
    else if world.(index).Map_data.name = name then Some index
    else from (index + 1)
  in
  from 0

let warp_arrival world warp =
  let ( let* ) = Option.bind in
  let* { to_map; to_point } = warp.destination in
  let* index = find world to_map in
  let* tile = Map_data.String_map.find_opt to_point world.(index).points in
  Some { map = index; tile }

(* The tile of [tiles] the connection on [side] leads onto from [here]: the
   edge row or column, shifted by the connection's offset. *)
let edge_entry (here : Tile_pos.t) (side : Direction.t) shift tiles : Tile_pos.t
    =
  let x = here.x - shift and y = here.y - shift in
  match side with
  | North -> { x; y = Grid.height tiles - 1 }
  | South -> { x; y = 0 }
  | West -> { x = Grid.width tiles - 1; y }
  | East -> { x = 0; y }

let across_edge world from side =
  let enter connection =
    if connection.side <> side then None
    else
      Option.bind (find world connection.connected_map) (fun index ->
          let tiles = world.(index).Map_data.tiles in
          let tile = edge_entry from.tile side connection.shift tiles in
          if Grid.contains tiles tile then Some { map = index; tile } else None)
  in
  List.find_map enter (map world from.map).connections

let neighbour world from direction =
  let ahead = Tile_pos.next from.tile direction in
  if Grid.contains (map world from.map).Map_data.tiles ahead then
    Some { from with tile = ahead }
  else across_edge world from direction

let overlaps start length other_start other_length =
  start < other_start + other_length && other_start < start + length

(* The side of [a] that [b] touches and the shift of [b]'s tiles along it,
   if their rectangles on the world grid meet along a side. *)
let touching (a : Map_data.t) wa (b : Map_data.t) wb =
  let aw = Grid.width a.tiles and ah = Grid.height a.tiles in
  let bw = Grid.width b.tiles and bh = Grid.height b.tiles in
  let pa = wa.offset and pb = wb.offset in
  let columns = overlaps pa.x aw pb.x bw and rows = overlaps pa.y ah pb.y bh in
  let joined side shift = Some { side; connected_map = b.name; shift } in
  if columns && pb.y + bh = pa.y then joined North (pb.x - pa.x)
  else if columns && pb.y = pa.y + ah then joined South (pb.x - pa.x)
  else if rows && pb.x + bw = pa.x then joined West (pb.y - pa.y)
  else if rows && pb.x = pa.x + aw then joined East (pb.y - pa.y)
  else None

let join_to maps (a : Map_data.t) =
  let connection_to (b : Map_data.t) =
    match (a.world, b.world) with
    | Some wa, Some wb when a.name <> b.name && wa.world_name = wb.world_name ->
        touching a wa b wb
    | _ -> None
  in
  let add connections (c : connection) =
    if
      List.exists
        (fun (e : connection) -> e.connected_map = c.connected_map)
        connections
    then connections
    else connections @ [ c ]
  in
  {
    a with
    connections =
      List.fold_left add a.connections (List.filter_map connection_to maps);
  }

let connect_by_world maps = List.map (join_to maps) maps
