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
  trainer_line : int;
      (** A tile in the line of a trainer who stands and looks one way: a battle
          the walk would rather not start, if they are not beaten yet. The
          fork's [LINE_TILE], as its story weighs it. *)
}

val default_costs : costs
(** Grass 3, warp 10, wander 8, trainer line 100. *)

type world = {
  maps : Connected_maps.t;
  hidden : Map_features.map_object -> bool;
      (** Whether the story has hidden the object (its [hide_flag] holds): it no
          longer stands in the way. *)
  costs : costs;
  edge_stalls : bool;
      (** Whether the game holds the player up a tile on each step onto a
          connected map while it loads the map (the fork's
          [RouteStep::connection_steps], measured on console B, 2026-11-03). On
          mGBA it does not: the fork's run of 2026-11-23 held "west 11" from
          Celadon City onto Route 16 for 10.5 tiles and ended on its tile, and
          ours, held a tile longer for the stall, ended a tile past it. *)
  cut : Gate_state.t;
      (** The cut trees cut since the last map change ({!with_tree_cut}): their
          gates open and their trees gone, as the fork's [tree_cut] opens them
          in its run state. *)
}

val world :
  ?hidden:(Map_features.map_object -> bool) ->
  ?edge_stalls:bool ->
  Connected_maps.t ->
  world
(** Every object shown, {!default_costs}, edges that stall (the console), no
    tree cut. *)

val with_tree_cut : world -> Connected_maps.place -> world option
(** The world with the cut tree on that tile cut: the fork's [tree_cut]
    (AutoStory/PokemonFRLG_AutoStoryBoulders) with [cut_gate_key]. [None] when
    no cut tree's gate has the tile. *)

val trees_regrown : world -> world
(** Every cut tree back: a cut tree's flag is temporary, so leaving its map
    regrows it (the fork's [regrow_on_warp]). *)

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

val sign_ahead : world -> Connected_maps.place -> Direction.t -> bool
(** Whether pressing the direction from the place reads a sign: one on the next
    tile, faced going north or south. *)

val walked_out_onto : world -> Connected_maps.place -> bool
(** Whether a warp that leaves the player on the place came out of a doorway
    above it, which the game walks the player out of before it takes input. *)

val hop_tiles : world -> Connected_maps.place -> Direction.t -> int
(** Tiles one press moves the player: 2 over a ledge, else 1. *)

val model : world -> Connected_maps.place Grid_planning.Step_model.t
