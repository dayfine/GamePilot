(** Workflow A state machine for BDSP Ramanas Park static legendary RNG
    manipulation.

    Implements the pedestal-first [0PK -> 1PK] soft-reset loop verified on live
    Switch hardware: 1. Freeze the player facing South at the empty [0PK]
    pedestal using a registered Bike key-item dialog and recover the 128-bit
    [Xorshift128] seed from ~40 player eye blinks. 2. Insert the slate, enter
    the Mystery Space, walk up to the legendary, face South, and re-freeze with
    the Bike dialog. 3. Re-identify the exact [1PK] advance anchor in the
    chamber (~10–15 player blinks). 4. Dismiss the dialog, turn North to face
    the legendary, search forward for the earliest matching shiny advance, and
    fire the timed confirm press via [submit_at]. 5. Detect shininess visually
    at battle start: stop parked on the shiny battle screen, or soft-reset via
    Switch HOME back to the saved pedestal and retry up to [max_attempts].

    GamePilot's own workflow orchestrator over {!Bdsp_actions} and {!Bdsp_rng};
    every game interaction is injected through {!game_steps} for deterministic
    scripted testing. *)

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

type game_steps = {
  log : string -> unit;
      (** Writes a progress line to the watch page / run log. *)
  update_counters : attempt:int -> max_attempts:int -> phase:string -> unit;
      (** Publishes live attempt and phase counters to the watch page. *)
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
  prepare_for_trigger : unit -> unit;
      (** Dismisses the Bike dialog and turns North to face the legendary right
          before scheduling the encounter presses. *)
  trigger_encounter :
    Bdsp_blink_rng.Static_rng_trigger.config ->
    Bdsp_blink_rng.In_chamber_reidentifier.anchor ->
    (Bdsp_blink_rng.Static_rng_trigger.outcome, string) result;
      (** Plans the next matching shiny advance and fires the timed confirm
          press. *)
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
