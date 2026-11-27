(** Schedules the final encounter confirmation input for a static legendary
    target, supporting both direct [pokemon_models = 0] triggers and single
    confirm presses placed inside a blink-free {!Static_timeline} gap.

    Port of the pure scheduling logic from the fork's
    [PokemonBDSP/Programs/RngManipulation/PokemonBDSP_StaticRngExecution.{h,cpp}]
    ([StaticPressSchedule], [schedule_static_presses]). *)

type timings = {
  ready_seconds : float;
      (** Earliest seconds after timeline start when the cry dialog is ready. *)
  guard_seconds : float;
      (** Minimum clearance in seconds to both adjacent blink edges. *)
  max_wait_seconds : float;
      (** Latest seconds after timeline start to search for a safe gap. *)
}
(** Timing bounds for placing a single confirm input on a simulated timeline. *)

val default_timings : timings
(** Ready at 5.0 s, 0.30 s guard margin on both sides, searching up to 20.0 s.
*)

type t = {
  span : int;
      (** Total RNG advances from the timeline start to Pokemon generation. *)
  confirm_seconds : float;
      (** Seconds from timeline start to the final confirm input. *)
  events_before_confirm : int;
      (** Number of simulated timeline events strictly before [confirm_seconds].
      *)
  gap_margin_seconds : float;
      (** Distance in seconds to the nearer adjacent blink edge. *)
}
(** A scheduled static encounter press ([StaticPressSchedule]). *)

val schedule :
  trigger_kind:Static_targets.trigger_kind ->
  context:Static_timeline.context ->
  timings:timings ->
  Xorshift128.state ->
  (t, string) result
(** Computes the {!t} schedule for [trigger_kind] starting from [state]:
    - [Direct_no_pokemon_model]: constant span
      [context.advance_delay + context.advances_after_accept] at
      [confirm_seconds = 0.0].
    - [Timeline_single_confirm]: simulates {!Static_timeline.simulate_timeline}
      and picks the earliest gap with at least [timings.guard_seconds] clearance
      on both sides and [confirm_seconds >= timings.ready_seconds]. *)
