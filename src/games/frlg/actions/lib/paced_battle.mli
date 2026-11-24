(** Finding a wild battle by pacing, for every action that fights wild battles
    on a spot: the grind ({!Grind}) and the PP drain ({!Berry_pp}), as the
    capture already does ({!Capture_steps}). One step [pace] from the patch's
    grass tile and back ({!Pacing_steps.find_encounter}, the fork's
    find_paced_encounter()).

    Where it differs: the fork's grind and PP drain turn in place
    ([spin_for_encounter()], Programs/MailGlitch/PokemonFRLG_MailGlitchBattle),
    reading the player's facing before each batch so that no turn tap is a step.
    GamePilot has no facing reader, and turning blind stepped the player off the
    grass (mg-05a testing 1 on mGBA: from Route 8 (45, 12) onto the path at (46,
    12), then no battle in 25 batches); pacing keeps the player on two known
    grass tiles. *)

val reckoned : Story.Pose.observed option -> Story.Pose.observed
(** The player's reckoned pose; fails as [position_unknown] without one. *)

val find :
  log:(string -> unit) ->
  pace:Grid_maps.Direction.t ->
  patch:Grid_maps.Tile_pos.t ->
  stands:(Story.Pose.observed -> unit) ->
  Story.Pose.observed ->
  unit
(** From where the player is reckoned to stand, which must be the patch or one
    tile [pace] from it (as the last search left them; else it fails as
    [off_patch]): paced until a wild battle starts, [stands] told where the
    player then stands. Fails as [no_encounter] after {!Pacing.max_steps} steps.
*)

val back_on_patch :
  pace:Grid_maps.Direction.t -> Story.Pose.observed -> Story.Pose.grid
(** The patch the player started on, facing [pace]: where an action that paced
    from it ends. *)
