(** A game's step model for the robust leg planner ({!Robust_planner}): where
    one step lands, and what the tile risks.

    Warps and game actions (doors, Surf, spin tiles) are not legs: a stop that
    isn't held is never used, so a plan never crosses a warp. Callers plan each
    stretch between warps on its own. *)

type 'state t = {
  compare_state : 'state -> 'state -> int;
      (** A total order on states, for the search's sets of them. *)
  step : 'state -> Direction.t -> 'state option;
      (** Where one step that way lands, or [None] if the player is stopped. *)
  step_tiles : 'state -> 'state -> int;
      (** How many tiles a step from the first state to the second counts: a
          ledge hop counts 2. *)
  held_at : 'state -> Direction.t -> bool;
      (** Whether the player, stopped, stays put however long the button is held
          (a wall). A stop that isn't held (a door, an exit off the maps) makes
          a leg the planner can't tell the end of, and is not used. *)
  wild : 'state -> bool;
      (** A place where a wild battle may stop the walk (tall grass). *)
  wander : 'state -> bool;  (** A place where someone wanders. *)
}

val of_step_model :
  ?wild:('state -> bool) ->
  ?wander:('state -> bool) ->
  ?step_tiles:('state -> 'state -> int) ->
  'state Grid_planning.Step_model.t ->
  'state t
(** The leg planner's step model ({!Grid_planning.Step_model}) as a robust one,
    so a game shares one step model between both planners. A step that warps or
    is a game action is a stop that isn't held. [wild] and [wander] default to
    no place, [step_tiles] to 1 a step. *)
