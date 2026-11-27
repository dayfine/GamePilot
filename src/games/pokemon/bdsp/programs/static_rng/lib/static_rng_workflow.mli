(** Workflow B state machine for BDSP static legendary RNG manipulation.

    Implements the full Ramanas Park / Sinnoh in-chamber [1PK] soft-reset loop
    from [docs/design/BDSP-Static-Legendary-RNG.md]: 1. Recover the 128-bit boot
    seed from Munchlax's intro blinks. 2. Enter the save (already facing the
    legendary in its chamber). 3. Re-identify the current advance anchor in the
    chamber ([1PK] model). 4. Search for the next target shiny advance and
    trigger the encounter with [submit_at]. 5. Detect shininess visually at
    battle start: stop immediately on [Shiny] (leaving the game parked on the
    battle screen ready for capture), or soft-reset via the Switch HOME menu and
    retry up to [max_attempts].

    GamePilot's own workflow orchestrator over {!Bdsp_actions} and {!Bdsp_rng};
    every game interaction is injected through {!game_steps} for deterministic
    scripted testing. *)

(** Final result of a Workflow B static RNG hunt. *)
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

type game_steps = {
  log : string -> unit;
      (** Writes a progress line to the watch page / run log. *)
  update_counters : attempt:int -> max_attempts:int -> phase:string -> unit;
      (** Publishes live attempt and phase counters to the watch page. *)
  recover_boot_seed :
    timeout_s:int ->
    (Bdsp_blink_rng.Munchlax_seed_finder.outcome, string) result;
      (** Recovers the 128-bit boot seed on the title/Munchlax intro screen. *)
  enter_save : unit -> (unit, string) result;
      (** Enters the save from the title screen into the overworld chamber. *)
  reidentify_in_chamber :
    base_state:Bdsp_rng.Xorshift128.state ->
    (Bdsp_blink_rng.In_chamber_reidentifier.anchor, string) result;
      (** Locks the current [1PK] advance anchor inside the chamber. *)
  face_target : unit -> unit;
      (** Turns the player North to face the static legendary right after [1PK]
          blink re-identification (during which the player faces South so the
          camera sees their eyes). *)
  trigger_encounter :
    Bdsp_blink_rng.Static_rng_trigger.config ->
    Bdsp_blink_rng.In_chamber_reidentifier.anchor ->
    (Bdsp_blink_rng.Static_rng_trigger.outcome, string) result;
      (** Plans the next matching shiny advance and fires the timed confirm
          press. *)
  detect_shiny : unit -> Bdsp_readers.Shiny_encounter_reader.reading;
      (** Watches the battle opening and classifies wild shininess. *)
  soft_reset : unit -> (unit, string) result;
      (** Closes and reopens the game from Switch HOME for the next attempt. *)
}
(** Game reads and actions Workflow B performs during each attempt. *)

val run : steps:game_steps -> Static_rng_options.t -> outcome
(** Runs Workflow B for up to [opts.max_attempts] attempts using [steps]. *)

val outcome_to_result : Static_rng_options.t -> outcome -> bool * string
(** Formats an {!outcome} into the [(passed, summary_line)] pair returned by the
    checkpoint action. *)
