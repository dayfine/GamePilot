open Grid_maps

type action = Walk | Surf | Face | Open_gate | Press_switch
type leg_end = Open | Wall | Warp

type t = {
  action : action;
  direction : Direction.t;
  tiles : int;
  leg_end : leg_end;
}

let end_text = function
  | Open -> "(open)"
  | Wall -> "(to wall)"
  | Warp -> "(warp)"

let to_string leg =
  let direction = Direction.name leg.direction in
  match leg.action with
  | Surf -> "surf " ^ direction
  | Face -> "face " ^ direction
  | Open_gate -> "open gate " ^ direction
  | Press_switch -> "press switch " ^ direction
  | Walk -> Printf.sprintf "%s %d %s" direction leg.tiles (end_text leg.leg_end)

type planned = { leg : t; after : Route_tile.t list }
