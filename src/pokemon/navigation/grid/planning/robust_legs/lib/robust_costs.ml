type t = {
  per_tile : int;
  per_wild_tile : int;
  per_wander_tile : int;
  per_leg : int;
  leg_not_at_wall : int;
  open_error : int;
  open_error_per : int;
  exact_open_tiles : int;
  per_open_tile : int;
  hold_open_legs : bool;
  per_open_wild_tile : int;
  forbid_along_wander : bool;
  max_open_tiles : int;
  max_spread : int;
  max_searched : int;
}

let default =
  {
    per_tile = 1;
    per_wild_tile = 4;
    per_wander_tile = 3;
    per_leg = 8;
    leg_not_at_wall = 50;
    open_error = 1;
    open_error_per = 5;
    exact_open_tiles = 0;
    per_open_tile = 0;
    hold_open_legs = false;
    per_open_wild_tile = 0;
    forbid_along_wander = true;
    max_open_tiles = 12;
    max_spread = 5;
    max_searched = 20000;
  }

let open_leg_error costs tiles =
  if tiles <= costs.exact_open_tiles then 0
  else if costs.open_error_per <= 0 then costs.open_error
  else costs.open_error + (tiles / costs.open_error_per)
