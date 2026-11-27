(** Closed-loop minimap navigator for the right half of the central Grand
    Underground Hideaway ring ([bottom_east], [east_vertical], [top_east]).

    Sprints directly to each active {!Bdsp_readers.Minimap_sparkles.target}
    bucket using the pink player dot position, then micro-probes the wall at
    that bucket and calls [on_prompt] whenever a dig dialog or wild battle
    triggers. *)

val primary_wall_dir :
  along_dir:Grid_geometry.Direction.t ->
  Grid_geometry.Direction.t list ->
  Grid_geometry.Direction.t
(** Default wall direction to face at a stop given its non-South adjacent walls.
*)

val wall_from_offset :
  along_dir:Grid_geometry.Direction.t ->
  wall_dirs:Grid_geometry.Direction.t list ->
  fallback:Grid_geometry.Direction.t ->
  Bdsp_readers.Wall_sparkle.offset ->
  Grid_geometry.Direction.t
(** Choose which adjacent non-South wall to face from a radar sparkle offset. *)

val servo_step_toward :
  face_dir:Grid_geometry.Direction.t ->
  Bdsp_readers.Wall_sparkle.offset ->
  Grid_geometry.Direction.t option
(** Step parallel to the wall [face_dir] toward the sparkle offset, or [None]
    when already aligned along that wall's axis. *)

val visit_targets :
  log:(string -> unit) ->
  picture:Wire.box ->
  start_door:Grid_geometry.Tile_pos.t ->
  sparkles:Bdsp_readers.Minimap_sparkles.nearby ->
  on_prompt:('a -> ('a * bool, string) result) ->
  on_battle:('a -> ('a, string) result) ->
  'a ->
  ('a * Grid_geometry.Tile_pos.t, string) result
(** Plan a route from [start_door] across each active sparkle waypoint, pulse
    radar ([R]) at each stop to visually lock onto the flashing sparkle star,
    and return to the nearest doorway. Returns [(final_state, return_door)]. *)

val route_to_first_stop :
  log:(string -> unit) ->
  picture:Wire.box ->
  start_door:Grid_geometry.Tile_pos.t ->
  sparkles:Bdsp_readers.Minimap_sparkles.nearby ->
  on_prompt:('a -> ('a * bool, string) result) ->
  on_battle:('a -> ('a, string) result) ->
  'a ->
  ('a, string) result
(** Isolated single-stop test: route from [start_door] to the first active
    sparkle waypoint, pulse [R] radar, visually lock onto the star, hug its
    wall, and press [A] (without returning to a doorway). *)
