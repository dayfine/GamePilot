(** What to do when a wandering person may have stopped a planned walk: at the
    end of a leg to a wall, partway along a leg, or on a leg that did not move
    at all. Each decision spends one of a limited number of waits for the person
    to step aside. *)

type policy = {
  max_waits : int;  (** Waits allowed per step or leg. *)
  wait_ms : int;  (** How long one wait lasts; the caller waits. *)
  probe_with_a : bool;
      (** The game checks a stop at a wall for a person by pressing A (BDSP)
          before waiting or replanning, instead of by movement or the screen
          (FRLG). *)
}
(** A game's rules for waiting on a wanderer. *)

type state = { waits_used : int }
(** Waits spent on the current step or leg. *)

val fresh : state
(** No waits spent: the state for a new step or leg. *)

type wall_stop = {
  touches_wander_zone : bool;
      (** The leg ends next to where a person wanders. *)
  probed_person : bool;
      (** Pressing A found a person; only read when [probe_with_a]. *)
}
(** A leg to a wall stopped: maybe at the wall, maybe at a person. *)

type wall_action =
  | Wait_and_rehold  (** Wait, then hold the leg's direction again. *)
  | Replan_before_zone
      (** Out of waits: plan a walk that stops before the wander zone. *)

val decide_wall : policy -> state -> wall_stop -> wall_action option * state
(** [None] when the stop is not near a wander zone, when [probe_with_a] and the
    probe found no one, or when the waits are spent and the game does not probe
    ([Replan_before_zone] is only for games that probe). *)

type mid_leg_stop = {
  wanderer_ahead : bool;  (** A wanderer blocks the tile ahead. *)
  can_resume_remaining : bool;
      (** The exact tile the player stopped on is known. *)
}
(** A leg stopped short of its end. *)

type mid_leg_action =
  | Wait_and_resume_remaining  (** Wait, then walk the rest of the leg. *)
  | Wait_and_reanchor
      (** Wait, then find where the player is before going on. *)

val decide_mid_leg :
  policy -> state -> mid_leg_stop -> mid_leg_action option * state
(** [None] when no wanderer is ahead or the waits are spent. *)

type unmoved_action = Wait_and_retry  (** Wait, then walk the leg again. *)

val decide_unmoved :
  policy -> state -> blocked_by_wanderer:bool -> unmoved_action option * state
(** For a leg that moved no tiles. [None] when no wanderer blocks the first tile
    or the waits are spent. *)
