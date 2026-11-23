type t = {
  direction : Grid_maps.Direction.t;
  tiles : int;
  to_wall : bool;
  tile_ms : int;
  stop_on_interrupt : bool;
  stop_if_blocked : bool;
  stalled_steps : int list;
}

let make ?(to_wall = false) ~tile_ms direction tiles =
  {
    direction;
    tiles;
    to_wall;
    tile_ms;
    stop_on_interrupt = false;
    stop_if_blocked = false;
    stalled_steps = [];
  }

let to_string leg =
  Printf.sprintf "%s %d%s"
    (Grid_maps.Direction.name leg.direction)
    leg.tiles
    (if leg.to_wall then " (to wall)" else "")

type result = { tiles : int; exact : bool; interruptions : int; stopped : bool }
