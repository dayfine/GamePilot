module String_map = Map.Make (String)
module String_set = Set.Make (String)

type t = {
  name : string;
  source : Map_features.source;
  world : Map_features.world option;
  allow_running : bool;
  tiles : Tile_kind.t Grid.t;
  elevation : int Grid.t option;
  points : Tile_pos.t String_map.t;
  regions : Tile_pos.t list String_map.t;
  warps : Map_features.warp list;
  objects : Map_features.map_object list;
  hidden_items : Map_features.hidden_item list;
  triggers : Map_features.trigger list;
  flag_sets : String_set.t String_map.t;
  connections : Map_features.connection list;
  patches : Map_features.patch list;
  gates : Map_gates.gate String_map.t;
  switches : Map_gates.switch String_map.t;
}

let warp_at map pos =
  List.find_opt
    (fun (warp : Map_features.warp) -> Tile_pos.equal warp.warp_pos pos)
    map.warps

let default_max_tiles = 50

let stops_walk : Tile_kind.t -> bool = function
  | Door | Wall | Outside -> true
  | _ -> false

let tiles_to_door ?(max_tiles = default_max_tiles) tiles from direction =
  let rec walk at count =
    let next = Tile_pos.next at direction in
    match Grid.find tiles next with
    | _ when count >= max_tiles -> count
    | None -> count
    | Some tile when stops_walk tile -> count + 1
    | Some _ -> walk next (count + 1)
  in
  walk from 0
