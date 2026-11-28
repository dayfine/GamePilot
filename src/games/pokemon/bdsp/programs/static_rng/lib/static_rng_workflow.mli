(** Location-aware state machine for BDSP static legendary RNG manipulation.

    Driven by {!Bdsp_rng.Static_targets.entry_mode} on the selected target:
    - {!Bdsp_rng.Static_targets.Ramanas_slate_chamber} (Kyogre, Groudon,
      Rayquaza, Ho-Oh, Lugia, Mewtwo, Regis, Birds, Beasts, Latis): recovers the
      128-bit [Xorshift128] seed from [0PK] player blinks at the empty pedestal,
      pre-checks for a nearby shiny advance, inserts the slate to warp into the
      Mystery Space, re-identifies under [1PK], and fires the timed confirm.
    - {!Bdsp_rng.Static_targets.Standing_at_encounter} (Dialga, Palkia, Uxie,
      Azelf, Giratina, Heatran, Regigigas, Darkrai, Arceus, Rotom): recovers the
      128-bit seed in place and feeds the anchored clock straight into
      {!game_steps.trigger_encounter}, skipping slate insertion and chamber
      re-identification.

    Adding a new static location only requires adding its descriptor to
    {!Bdsp_rng.Static_targets.all} (and, if it has a new entry sequence, adding
    an {!Bdsp_rng.Static_targets.entry_mode} variant). Every game interaction is
    injected through {!game_steps} for deterministic scripted testing. *)

(** Final result of a Workflow A static RNG hunt. *)
type outcome =
  | Shiny_found of {
      attempt : int;
      hit : Bdsp_rng.Static_encounter.hit;
      reading : Bdsp_readers.Shiny_encounter_reader.reading;
    }
      (** Confirmed a shiny encounter on [attempt]; the game is left parked on
          the battle screen ready for capture. *)
  | Exhausted of { attempts : int; last_reason : string }
      (** Stopped without confirming a shiny encounter after [attempts] tries,
          carrying the last failure or miss reason. *)

type countdown = {
  remaining_ms : int;  (** Remaining wait time in milliseconds. *)
  until_ms : int;
      (** Target wall-clock time in Unix epoch milliseconds, for live watch-page
          ticking. *)
}
(** Live countdown metadata attached to a watch counter update. *)

val format_countdown_ms : int -> string
(** Formats a non-negative duration in milliseconds as [M:SS] or [H:MM:SS],
    rounding up partial seconds and clamping at [0:00]. *)

val format_target : Bdsp_rng.Static_encounter.hit -> string
(** Formats a planned hit's shiny type and nature (e.g. ["Star Shiny Modest"])
    for the watch page's [Target] counter. *)

val watch_counters :
  attempt:int ->
  max_attempts:int ->
  phase:string ->
  ?target:string ->
  ?countdown:countdown ->
  unit ->
  Wire.Watch.counter list
(** Builds the [watch.counters] items for the current attempt, phase, optional
    target description, and optional live countdown. *)

type game_steps = {
  log : string -> unit;
      (** Writes a progress line to the watch page / run log. *)
  show_counters : Wire.Watch.counter list -> unit;
      (** Publishes live [watch.counters] updates to the watch page. *)
  freeze_player : unit -> unit;
      (** Opens the Bike key-item dialog ([+ -> Right]) so the player stands
          frozen facing South with no idle head fidgets. *)
  recover_pedestal_seed :
    timeout_s:int -> (Pedestal_seed_finder.outcome, string) result;
      (** Recovers the confirmed 128-bit seed from [0PK] player blinks at the
          empty pedestal. *)
  enter_chamber : unit -> (unit, string) result;
      (** Dismisses the Bike dialog, inserts the slate at the pedestal, enters
          the Mystery Space, walks up to the legendary, turns South, and opens
          the Bike dialog. *)
  reidentify_in_chamber :
    base_state:Bdsp_rng.Xorshift128.state ->
    (Bdsp_blink_rng.In_chamber_reidentifier.anchor, string) result;
      (** Locks the current [1PK] advance anchor inside the Mystery Space. *)
  trigger_encounter :
    on_phase:
      (phase:string -> ?target:string -> ?countdown:countdown -> unit -> unit) ->
    Bdsp_blink_rng.Static_rng_trigger.config ->
    Bdsp_blink_rng.In_chamber_reidentifier.anchor ->
    (Bdsp_blink_rng.Static_rng_trigger.outcome, string) result;
      (** Plans the next matching shiny advance, optionally re-anchors when far
          away, dismisses the freeze dialog, faces North, and fires the timed
          confirm press, reporting wait/re-anchor/trigger phases via [on_phase].
      *)
  detect_shiny : unit -> Bdsp_readers.Shiny_encounter_reader.reading;
      (** Watches the battle opening and classifies wild shininess. *)
  soft_reset_to_pedestal : unit -> (unit, string) result;
      (** Closes and reopens the game from Switch HOME and loads back into the
          saved empty pedestal room for the next attempt. *)
}
(** Game reads and actions Workflow A performs during each attempt. *)

val run : steps:game_steps -> Static_rng_options.t -> outcome
(** Runs Workflow A for up to [opts.max_attempts] attempts using [steps]. *)

val outcome_to_result : Static_rng_options.t -> outcome -> bool * string
(** Formats an {!outcome} into the [(passed, summary_line)] pair returned by the
    checkpoint action. *)
