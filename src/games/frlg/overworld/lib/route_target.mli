(** Plans a story [route] event's walk: from where the player stands to a plan's
    target pose (a map, the tiles that will do, the way to face), with
    {!Frlg_steps} and the shared leg planner. Pure. *)

open Grid_maps

val place_of :
  Frlg_steps.world ->
  Checkpoints.Pose.observed ->
  (Connected_maps.place, string) result
(** The observed pose's place, or why there is none (its map is not loaded). *)

val observed_of :
  Frlg_steps.world ->
  Connected_maps.place ->
  Direction.t option ->
  Checkpoints.Pose.observed

val at_target :
  Frlg_steps.world -> Checkpoints.Pose.grid -> Connected_maps.place -> bool
(** On the target's map, on one of its tiles (any, when it lists none). *)

val plan :
  Frlg_steps.world ->
  from:Connected_maps.place ->
  facing:Direction.t option ->
  Checkpoints.Pose.grid ->
  (Connected_maps.place Grid_planning.Leg.t list, string) result
(** The cheapest legs to the target, ending facing its way when it names one; an
    error names the target when its map is not loaded or no walk reaches it. *)
