(** Pure decision policy for automated Pokémon catching.

    Evaluates a {!Catch_state.policy} against the current {!Catch_state.t} at
    each battle action menu using a fixed safety-first priority order:
    + Turn and ball limits (pause before Struggle or ball exhaustion).
    + Active member survival (when [active_hp_ratio] is known and below
      [hp_floor], heal or retreat to a healthy wall; falls back to
      {!Catch_state.Heal_active} when no healthy wall is available).
    + HP chipping via a healthy False Swiper (when [foe_hp_ratio] is known and
      above threshold; applies status first when [require_status] is set). Uses
      [foe_hp_target] before the first ball and [foe_hp_rechip] after, so
      healing moves like Aqua Ring or Rest trigger re-chipping cleanly.
    + Status maintenance when [reapply_status] is enabled, [foe_status] is
      [Some Healthy], and the [status_setter] is not fainted.
    + Ball throw (retreating a fragile [require_status] False Swiper to a
      healthy wall first when one is configured).

    {!decide} never emits {!Catch_state.Switch_to} for a slot in
    [state.fainted]. *)

val decide : Catch_state.policy -> Catch_state.t -> Catch_state.command
(** Choose the next {!Catch_state.command} for the observed battle state. *)

val next_send_in : Catch_state.policy -> fainted:int list -> int option
(** First slot in [policy.send_in_order] not present in [fainted], or [None]
    when no healthy send-in remains. *)
