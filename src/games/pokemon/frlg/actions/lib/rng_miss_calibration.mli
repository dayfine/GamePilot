(** Live RNG miss-distance reporting and Switch timing auto-calibration shared
    by {!Gift_rng} and {!Wild_rng}.

    On a non-shiny Summary observation, looks up the species in
    {!Frlg_rng.Base_stats}, searches nearby Method 1 seeds and advances with
    {!Frlg_rng.Rng_miss_search.search_method1}, logs the observed Pokémon and
    miss report, and optionally persists the [(boot_delta_ms, ingame_delta)]
    correction via {!Frlg_rng.Switch_rng_calibration.record_timing_miss}. *)

val report_and_calibrate :
  log:(string -> unit) ->
  label:string ->
  species:string ->
  seeds:string ->
  seed_shift:int ->
  target_seed:int ->
  target_delay_ms:int ->
  target_advance:int ->
  persist:bool ->
  ?calibration_path:string ->
  Frlg_rng.Rng_miss_search.observation ->
  (int * int) option
(** Logs [obs], searches for the landed Method 1 seed and advance, logs the miss
    report, and returns [Some (boot_delta_ms, ingame_delta)] when at least one
    match is found (taking the closest match). When [persist] is [true], also
    updates {!Frlg_rng.Switch_rng_calibration.record_timing_miss} (logging a
    warning on I/O failure). *)
