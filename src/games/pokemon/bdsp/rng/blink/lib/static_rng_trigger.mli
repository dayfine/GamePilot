(** Static legendary encounter target search and [submit_at]-timed trigger.

    Given a {!Bdsp_rng.Static_targets.t} (such as Kyogre or Groudon), an
    acceptance predicate over {!Bdsp_rng.Static_encounter.pokemon}, and a locked
    {!In_chamber_reidentifier.anchor}:
    - searches forward via {!Bdsp_rng.Static_encounter.searcher} for the
      earliest reachable target advance within [min_wait_advances] and
      [max_wait_advances];
    - computes the exact confirm schedule via
      {!Bdsp_rng.Static_press_schedule.schedule};
    - waits until the cry-dialog open time while silently renewing the input
      lease via {!Effects.renew_lease} every ~30 s;
    - opens the cry dialog with [A] (for [Timeline_single_confirm] targets) and
      schedules the final encounter confirm press at the exact monotonic daemon
      timestamp via {!Effects.submit_at}.

    Implements the static execution workflow from
    [docs/design/BDSP-Static-Legendary-RNG.md] (§1.4,
    https://github.com/dayfine/Arduino-Source/pull/782). *)

type search_config = {
  tsv : int;  (** Trainer Shiny Value (0 suffices for shiny/stat prediction). *)
  synchronize_nature : int option;
      (** Optional Synchronize lead nature index (0-24), or [None]. *)
  min_wait_advances : int;
      (** Minimum advances after the anchor blink before target generation. *)
  max_wait_advances : int;
      (** Maximum advances after the anchor blink to search forward. *)
  accept : Bdsp_rng.Static_encounter.pokemon -> bool;
      (** Target filter predicate (e.g. shiny check). *)
}
(** Forward target-search parameters for {!plan} and {!run}. *)

type config = {
  target : Bdsp_rng.Static_targets.t;
      (** Static encounter descriptor (e.g. Kyogre, Groudon). *)
  search : search_config;  (** Search window and acceptance predicate. *)
  timings : Bdsp_rng.Static_press_schedule.timings;
      (** Cry-dialog readiness and blink-gap guard margins. *)
  white_delay_seconds : float;
      (** Transition delay before timeline actors initialize (default 0.0 s). *)
  advance_delay : int;
      (** Fixed advances consumed before timeline start (default 0). *)
  aim_offset_ms : float;
      (** Calibration offset in ms added to [confirm_t_ms] (default 0.0 ms). *)
  lease_renew_seconds : float;
      (** Interval between silent {!Effects.renew_lease} calls while waiting
          (default 30.0 s). *)
}
(** Configuration for {!plan} and {!run}. *)

val default_config :
  target:Bdsp_rng.Static_targets.t ->
  accept:(Bdsp_rng.Static_encounter.pokemon -> bool) ->
  config
(** Default static trigger configuration: [tsv = 0], no Synchronize,
    [min_wait_advances = 20], [max_wait_advances = 5000],
    {!Bdsp_rng.Static_press_schedule.default_timings}, zero calibration offset,
    and 30 s lease renewal. *)

type plan = {
  hit : Bdsp_rng.Static_encounter.hit;  (** Selected target hit and Pokemon. *)
  timeline_start_advance : int;
      (** Advance at which the trigger timeline begins (cry dialog open). *)
  schedule : Bdsp_rng.Static_press_schedule.t;
      (** Exact press schedule from [timeline_start_advance] to [hit.advances].
      *)
  open_t_ms : float;
      (** Daemon clock timestamp in ms to begin the trigger timeline. *)
  confirm_t_ms : float;
      (** Exact daemon clock timestamp in ms passed to {!Effects.submit_at} for
          the final encounter confirm press. *)
}
(** Computed encounter trigger schedule from {!plan}. *)

type outcome = {
  plan : plan;  (** The executed trigger plan. *)
  batch_done : Wire.batch_done;
      (** Daemon completion notification for the {!Effects.submit_at} press. *)
}
(** Result returned by {!run} after the timed confirm press completes. *)

val plan : config -> In_chamber_reidentifier.anchor -> (plan, string) result
(** Purely searches forward from [anchor] and computes the earliest reachable
    {!plan} without performing effects. *)

val run : config -> In_chamber_reidentifier.anchor -> (outcome, string) result
(** Computes {!plan}, waits until [open_t_ms] while renewing the lease every
    [lease_renew_seconds], opens the cry dialog (for [Timeline_single_confirm]),
    and submits the final encounter confirm press at [confirm_t_ms] via
    {!Effects.submit_at}. *)
