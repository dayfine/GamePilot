(** FireRed's step model on foot: what pressing a direction once does, over the
    maps joined by their warps and edges ({!Grid_maps.Connected_maps}). Ported
    from the fork's Overworld/PokemonFRLG_OverworldRoute ([press()],
    [stops_at()]) and PokemonFRLG_OverworldTileRules, for the leg planner.

    - An exit mat (a warp walked off its way) or a door ahead going north takes
      the warp without a step; a step onto a ladder or a cave mouth takes it
      after the step.
    - Arriving on a door or a cave mouth, the game walks the player a tile
      south, facing south; arriving on an exit mat, they face away from it.
    - A ledge walked into its way hops the player over it, two tiles.
    - Walls, water, signs, closed gates, people and items stop the player.

    Not modelled yet, so never planned through: Surf, spin and ice floors,
    holes, elevation, and gates the story opens. *)

open Grid_maps

type costs = {
  grass : int;  (** On top of a tile, for a step into tall grass. *)
  warp : int;  (** A warp's fade. *)
  wander : int;  (** A tile someone may wander onto. *)
}

val default_costs : costs
(** Grass 3, warp 10, wander 8. *)

type world = {
  maps : Connected_maps.t;
  hidden : Map_features.map_object -> bool;
      (** Whether the story has hidden the object (its [hide_flag] holds): it no
          longer stands in the way. *)
  costs : costs;
}

val world :
  ?hidden:(Map_features.map_object -> bool) -> Connected_maps.t -> world
(** Every object shown, {!default_costs}. *)

val press :
  world ->
  Connected_maps.place ->
  Direction.t ->
  Connected_maps.place Grid_planning.Leg.step option
(** What pressing the direction once does from the place, or [None] if the
    player can't go that way. *)

val held_at : world -> Connected_maps.place -> Direction.t -> bool
(** Whether holding the direction keeps the player on the place: a wall, but not
    a sign read going north or south, a ledge, someone who may walk off or a
    trainer, an edge onto another map, or a warp to a map not loaded. *)

val hop_tiles : world -> Connected_maps.place -> Direction.t -> int
(** Tiles one press moves the player: 2 over a ledge, else 1. *)

val model : world -> Connected_maps.place Grid_planning.Step_model.t
