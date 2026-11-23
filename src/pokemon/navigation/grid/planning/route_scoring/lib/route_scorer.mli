(** Scores a walk plan on a tile grid: how long it takes on the game's measured
    paces, from every tile the player may start on, and whether it can go wrong.
    A leg held to a wall ends where the wall stops it; a leg of taps moves
    exactly its taps; a held open leg may end a few tiles short or long, and
    those tiles must be safe. Interruptions on the way (a wild battle in grass,
    someone walking about, a trainer's sight) are charged by their chance times
    the recovery they need, and a recovery that can lead back into itself
    strands the player: the plan fails.

    Game-neutral: the game supplies the step rules and tile risks
    ({!Score_map}), its paces and hold error ({!Route_paces}), how often and how
    dearly it is interrupted ({!Interrupt_model}) and, for recoveries, its
    replanner. Tiles that move the player on their own (spinners, currents) are
    not modelled yet. *)

type replanner = Tile_pos.t list -> Scored_leg.t list option
(** A new plan from the tiles an interruption may have left the player on, or
    [None] if none exists. *)

val score :
  ?replan:replanner ->
  Score_map.t ->
  Route_paces.t ->
  Interrupt_model.t ->
  from:Tile_pos.t list ->
  goal:(Tile_pos.t -> bool) ->
  Scored_leg.t list ->
  Route_score.t
(** Scores the legs walked from any of [from] toward tiles [goal] accepts.
    Without [replan], a recovery that needs a new plan fails. *)
