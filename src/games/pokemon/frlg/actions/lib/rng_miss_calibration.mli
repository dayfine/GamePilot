(** Live RNG miss-distance reporting and Switch timing auto-calibration shared
    by {!Gift_rng} and {!Wild_rng}.

    On a non-shiny Summary observation, looks up the species in
    {!Frlg_rng.Base_stats}, searches nearby seeds and advances with
    {!Frlg_rng.Rng_miss_search.search_method1} (gifts) or
    {!Frlg_rng.Rng_miss_search.search_wild} (wild encounters), logs the observed
    Pokémon and miss report, and optionally persists the
    [(boot_delta_ms, ingame_delta)] correction via
    {!Frlg_rng.Switch_rng_calibration.record_timing_miss}. *)

type summary_miss = {
  species : string option;
      (** Species slug read from Summary Page 1 ({!Party_species.read_shown}),
          or [None] if unread. *)
  observation : Frlg_rng.Rng_miss_search.observation;
      (** Level, nature, gender, and optional Page 2 stats read from Summary. *)
}
(** Summary Page 1 + Page 2 data read on a non-shiny miss. *)

val read_summary_miss : unit -> summary_miss option
(** From an open Summary Page 1: reads level, species, nature, and gender, then
    turns to Page 2 to read the 6 stats ({!Frlg_text.Summary_stats}). Returns
    [None] if level cannot be read. *)

type delta = {
  boot_delta_ms : int;
      (** Millisecond correction to add to [boot_offset_ms] (halved on ±1-frame
          oscillation when [prev_seed_delta] is supplied). *)
  ingame_delta : int;  (** Advance correction to add to [ingame_offset]. *)
  seed_delta_frames : int;
      (** Observed seed miss in frames from the closest hit, to pass back as
          [prev_seed_delta] on the next attempt. *)
}
(** Timing correction and observed seed miss returned by {!report_and_calibrate}
    and {!report_and_calibrate_wild}. *)

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
  ?prev_seed_delta:int ->
  ?calibration_path:string ->
  Frlg_rng.Rng_miss_search.observation ->
  delta option
(** Logs [obs], searches for the landed Method 1 seed and advance, logs the miss
    report, and returns [Some delta] when at least one match is found (taking
    the closest match and damping ±1-frame seed oscillation via
    {!Frlg_rng.Rng_miss_search.damped_calibration_delta}). When [persist] is
    [true], also updates {!Frlg_rng.Switch_rng_calibration.record_timing_miss}
    (logging a warning on I/O failure). *)

val report_and_calibrate_wild :
  log:(string -> unit) ->
  label:string ->
  species:string ->
  slots:Frlg_rng.Wild_encounter.slot array ->
  super_rod:bool ->
  seeds:string ->
  seed_shift:int ->
  target_seed:int ->
  target_delay_ms:int ->
  target_advance:int ->
  persist:bool ->
  ?prev_seed_delta:int ->
  ?calibration_path:string ->
  Frlg_rng.Rng_miss_search.observation ->
  delta option
(** Like {!report_and_calibrate}, but searches wild encounters via
    {!Frlg_rng.Rng_miss_search.search_wild} using [slots], [super_rod], and the
    caught [species]'s base stats. *)
