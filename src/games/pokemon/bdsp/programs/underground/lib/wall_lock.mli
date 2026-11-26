(** Radar star locking and wall-alignment helpers for Grand Underground stops.

    Pulses [R] radar, diffs [core.find@1] sparkle-star blobs before and after,
    computes the wall to face and proportional multi-tile step along that wall,
    and re-probes [+3 / -3] tiles along the corridor if the initial stop sees no
    star. *)

val primary_wall_dir :
  along_dir:Bdsp_underground.Corridor_nav.direction ->
  Grid_geometry.Direction.t list ->
  Bdsp_underground.Corridor_nav.direction
(** Default wall direction to face at a stop given its non-South adjacent walls.
*)

val wall_from_offset :
  along_dir:Bdsp_underground.Corridor_nav.direction ->
  wall_dirs:Grid_geometry.Direction.t list ->
  fallback:Bdsp_underground.Corridor_nav.direction ->
  Bdsp_readers.Wall_sparkle.offset ->
  Bdsp_underground.Corridor_nav.direction
(** Choose which adjacent non-South wall to face from a radar sparkle offset. *)

val servo_step_toward :
  face_dir:Bdsp_underground.Corridor_nav.direction ->
  Bdsp_readers.Wall_sparkle.offset ->
  Bdsp_underground.Corridor_nav.direction option
(** Step parallel to the wall [face_dir] toward the sparkle offset, or [None]
    when already aligned along that wall's axis. *)

val servo_hold_ms :
  face_dir:Bdsp_underground.Corridor_nav.direction ->
  Bdsp_readers.Wall_sparkle.offset ->
  int
(** Proportional run hold duration in ms to reach the star along [face_dir]'s
    wall in one move. *)

val interact_at_stop :
  log:(string -> unit) ->
  picture:Wire.box ->
  on_prompt:('a -> ('a * bool, string) result) ->
  on_battle:('a -> ('a, string) result) ->
  along_dir:Bdsp_underground.Corridor_nav.direction ->
  wall_dirs:Grid_geometry.Direction.t list ->
  tile:Grid_geometry.Tile_pos.t ->
  re_seat:bool ->
  'a ->
  ('a, string) result
(** Pulse radar at a stop (with [+3 / -3] tile fallback), lock onto any flashing
    sparkle star, hug its wall, and interact with [A]. *)
