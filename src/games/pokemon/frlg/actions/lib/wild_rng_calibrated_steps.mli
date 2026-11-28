(** Live calibrated {!Wild_rng.game_steps} for ["wild_rng"]: recomputes
    {!Wild_rng_plan.target} between attempts, runs fast throw-only calibration
    catches on Switch visual misses, updates the rolling calibrator
    ({!Frlg_rng.Rolling_calibrator}) and persisted console offsets
    ({!Rng_miss_calibration}), and skips parity-locked [(seed, advance)]
    targets. *)

val make :
  log:(string -> unit) ->
  ?reset_mode:Rng_reset.mode ->
  find_encounter:
    (log:(string -> unit) ->
    reset_mode:Rng_reset.mode ->
    encounter_method:Wild_rng_plan.encounter_method ->
    Frlg_rng.Rng_timings.t ->
    unit ->
    bool) ->
  game_steps:
    (log:(string -> unit) ->
    reset_mode:Rng_reset.mode ->
    encounter_method:Wild_rng_plan.encounter_method ->
    Frlg_rng.Rng_timings.t ->
    Capture_plan.t ->
    Capture.game_steps) ->
  policy_catch_steps:
    (log:(string -> unit) ->
    reset_mode:Rng_reset.mode ->
    encounter_method:Wild_rng_plan.encounter_method ->
    timings:Frlg_rng.Rng_timings.t ->
    visual_shiny_check:bool ->
    on_miss:(party:int -> unit) ->
    config:Battle_catch_steps.config ->
    policy:Pokemon_catch.Catch_state.policy ->
    unit ->
    Wild_rng.policy_catch_steps) ->
  check_summary:
    (log:(string -> unit) ->
    slot:int ->
    read_miss:bool ->
    [ `Shiny | `Not_shiny of Rng_miss_calibration.summary_miss option ]) ->
  Wild_rng_plan.t ->
  Frlg_rng.Wild_target.t ->
  Wild_rng.game_steps
(** Builds live calibrated {!Wild_rng.game_steps} from the low-level
    {!Wild_rng_steps} primitives. *)
