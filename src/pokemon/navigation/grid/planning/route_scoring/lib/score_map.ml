type risk = No_risk | Encounter | Wanderer | Sight | Warp | Trigger

type t = {
  step : Tile_pos.t -> Direction.t -> Tile_pos.t option;
  risk : Tile_pos.t -> risk;
}

let stops_on = function
  | Warp | Trigger -> true
  | No_risk | Encounter | Wanderer | Sight -> false

let walk_steps map from direction ~most =
  let rec go at taken path =
    if taken >= most then path
    else
      match map.step at direction with
      | None -> path
      | Some next ->
          if stops_on (map.risk next) then next :: path
          else go next (taken + 1) (next :: path)
  in
  List.rev (go from 0 [])
