type t = {
  direction : Grid_geometry.Direction.t;
  tiles : int;
  to_wall : bool;
  tile_ms : int;
  stop_on_interrupt : bool;
  stop_if_blocked : bool;
  stalled_steps : int list;
  slow_steps : int list;
  slow_step_ms : int;
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
    slow_steps = [];
    slow_step_ms = tile_ms;
  }

let to_string leg =
  Printf.sprintf "%s %d%s"
    (Grid_geometry.Direction.name leg.direction)
    leg.tiles
    (if leg.to_wall then " (to wall)" else "")

type result = { tiles : int; exact : bool; interruptions : int; stopped : bool }
