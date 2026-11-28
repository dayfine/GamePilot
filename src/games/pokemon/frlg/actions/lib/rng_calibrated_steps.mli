(** Shared catch, Summary check, and live rolling auto-calibration builder for
    {!Wild_rng} and {!Static_rng}.

    Recomputes targets on subsequent attempts, reads Summary Page 1 & Page 2 on
    Switch misses (including fast throw-only catch with [cal_ball_row] on visual
    misses), updates rolling offsets via {!Frlg_rng.Rolling_calibrator}, and
    skips parity-locked [(seed, advance)] targets. *)

val capture_steps :
  log:(string -> unit) ->
  ?show_counters:(Wire.Watch.counter list -> unit) ->
  find_encounter:(unit -> bool) ->
  Capture_plan.t ->
  Capture.game_steps
(** {!Capture_steps} wired with [find_encounter], [watch.counters], and no flee.
*)

val legacy_catch :
  log:(string -> unit) ->
  ?show_counters:(Wire.Watch.counter list -> unit) ->
  find_encounter:(unit -> bool) ->
  Capture_plan.t ->
  party:int ->
  Capture.result
(** Runs {!Capture.run} under {!Frlg_battle.Battle_look.probes} with
    [find_encounter] and no flee. *)

val make_policy_catch :
  log:(string -> unit) ->
  find_encounter:(unit -> bool) ->
  visual_shiny_check:bool ->
  on_miss:(party:int -> unit) ->
  config:Battle_catch_steps.config ->
  policy:Pokemon_catch.Catch_state.policy ->
  Wild_rng.policy_catch_steps
(** Builds {!Wild_rng.policy_catch_steps} from a battle starter, optional visual
    shiny detector, and {!Battle_catch_steps} policy. *)

val policy_catch_for :
  log:(string -> unit) ->
  find_encounter:(unit -> bool) ->
  ?on_miss:(party:int -> unit) ->
  catch_mode:Wild_rng_plan.catch_mode ->
  visual_shiny_check:bool ->
  Capture_plan.t ->
  Wild_rng.policy_catch_steps option
(** Selects {!Wild_rng.policy_catch_steps} or [None] (legacy throw-only) from
    [catch_mode] and [visual_shiny_check]. *)

val check_summary :
  log:(string -> unit) ->
  slot:int ->
  read_miss:bool ->
  [ `Shiny | `Not_shiny of Rng_miss_calibration.summary_miss option ]
(** From the overworld: opens [slot]'s Summary Page 1, checks the shiny star,
    and optionally reads Page 1 & Page 2 stats on a miss. *)

type rng_target = {
  seed : int;  (** Target 16-bit initial seed. *)
  table_delay_ms : int;  (** Seed table delay in ms for [seed]. *)
  advance : int;  (** Target RNG advance. *)
  timings : Frlg_rng.Rng_timings.t;  (** Computed waits for this target. *)
  description : string;  (** Human-readable target description for logs. *)
}
(** Common target projection shared by wild and static RNG auto-calibration. *)

type spec = {
  prefix : string;  (** Log prefix, e.g. ["Wild RNG"] or ["Static RNG"]. *)
  is_switch : bool;
      (** When [true], enables fast throw-only miss catch, Summary miss reading,
          and parity-lock target skipping. *)
  total_attempts : int;  (** Total attempt budget shown in attempt logs. *)
  cal_ball_row : int;
      (** 0-based Poké Balls pocket row thrown on visual miss calibration. *)
  capture : Capture_plan.t;  (** Capture target, ball, and ball budget. *)
  catch_mode : Wild_rng_plan.catch_mode;  (** Catch strategy. *)
  visual_shiny_check : bool;  (** Whether battle-intro shiny detection runs. *)
  initial_boot_offset_ms : int;  (** Starting boot timing offset in ms. *)
  initial_ingame_offset : int;  (** Starting in-game advance offset. *)
  initial_target : rng_target;  (** Target for attempt 1. *)
  find_target :
    boot_offset_ms:int ->
    ingame_offset:int ->
    exclude_targets:(int * int) list ->
    (rng_target, string) result;
      (** Recomputes the next target after an offset update or parity skip. *)
  find_encounter : Frlg_rng.Rng_timings.t -> unit -> bool;
      (** Hard-resets, submits blind presses, and waits for battle. *)
  calibrate_miss :
    label:string ->
    target:rng_target ->
    calibrator:Frlg_rng.Rolling_calibrator.t ->
    used_boot_offset_ms:int ->
    used_ingame_offset:int ->
    Rng_miss_calibration.summary_miss ->
    (Frlg_rng.Rolling_calibrator.t * Frlg_rng.Rolling_calibrator.estimate)
    option;
      (** Searches a Summary miss and feeds it to
          {!Frlg_rng.Rolling_calibrator}. *)
}
(** Encounter-specific hooks supplied to {!make}. *)

val make :
  log:(string -> unit) ->
  ?show_counters:(Wire.Watch.counter list -> unit) ->
  spec ->
  Wild_rng.game_steps
(** Builds live {!Wild_rng.game_steps} with rolling Switch auto-calibration. *)
