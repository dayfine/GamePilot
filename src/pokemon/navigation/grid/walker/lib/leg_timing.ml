(* A leg to a wall is held this many tiles past its last, so the wall, not
   the hold, stops it. *)
let wall_extra_tiles = 2

let hold_ms (leg : Leg_spec.t) tiles =
  let first = leg.tiles - tiles + 1 in
  let count steps =
    List.length (List.filter (fun s -> s >= first && s <= leg.tiles) steps)
  in
  let stalled =
    (leg.tile_ms * count leg.stalled_steps)
    + ((leg.slow_step_ms - leg.tile_ms) * count leg.slow_steps)
  in
  let half_tile = leg.tile_ms / 2 in
  if leg.to_wall then (leg.tile_ms * (tiles + wall_extra_tiles)) + stalled
  else (leg.tile_ms * (tiles - 1)) + half_tile + stalled

let tiles_before_interrupt (leg : Leg_spec.t) ~elapsed_ms ~detection_delay_ms
    ~remaining =
  let since_first_step = elapsed_ms - detection_delay_ms + (leg.tile_ms / 2) in
  if since_first_step <= 0 then 0
  else max 0 (min remaining (since_first_step / leg.tile_ms))
