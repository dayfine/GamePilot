(** Pure decision policy for automated legendary catching.

    Evaluates a {!Catch_state.policy} against the current {!Catch_state.t} at
    each battle action menu using a fixed safety-first priority order:
    + Turn and ball limits (pause before Struggle or ball exhaustion).
    + Active member survival (heal or retreat to the wall below [hp_floor]).
    + HP chipping via False Swipe (sleeping first when [require_sleep] is set).
      Uses [foe_hp_target] before the first ball and [foe_hp_rechip] after, so
      healing moves like Aqua Ring or Rest trigger re-chipping cleanly.
    + Sleep maintenance when [reapply_sleep] is enabled.
    + Ball throw (retreating a fragile [require_sleep] False Swiper to the wall
      first). *)

val decide : Catch_state.policy -> Catch_state.t -> Catch_state.command
(** Choose the next {!Catch_state.command} for the observed battle state. *)

val next_send_in : Catch_state.policy -> fainted:int list -> int option
(** First slot in [policy.send_in_order] not present in [fainted], or [None]
    when no healthy send-in remains. *)
