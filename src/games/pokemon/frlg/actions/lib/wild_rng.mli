(** The ["wild_rng"] game action's decisions: with a party slot free, either the
    legacy throw-only capture on the blind RNG steps ({!Wild_rng_steps}) or an
    optional pre-turn-1 visual shiny check
    ({!Frlg_readers.Shiny_encounter_detector}) followed by
    {!Pokemon_catch.Catch_runner} ({!Battle_catch_steps}), then the catch's
    summary, which must show the shiny star. Ported from the program loop in
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_WildRng.cpp]
    (https://github.com/PokemonAutomation/Arduino-Source; reset and blind
    sequence, shiny check, catch).

    Where it differs: the fork checks for the shiny sound before catching;
    GamePilot has no audio probe, so it either checks visual battle-intro timing
    ({!Frlg_readers.Shiny_encounter_detector}) to skip catch turns and Luxury or
    Ultra Balls on misses (with an optional miss-calibration hook) or catches
    first on mGBA, and always confirms {!Frlg_readers.Shiny_star} on Summary
    before succeeding. The catch goes to the party, where its summary can be
    read: a full party fails before the first press. *)

type policy_catch_steps = {
  find_encounter : unit -> bool;
      (** Hard reset, blind presses, and wait for the wild battle screen. *)
  detect_shiny : (unit -> Frlg_readers.Shiny_encounter_reader.reading) option;
      (** Optional visual battle-intro shiny detector run before turn 1. When
          [Some f] returns [Not_shiny], [catch_battle] is skipped and [on_miss]
          runs instead. *)
  on_miss : unit -> unit;
      (** Hook invoked on a visual [Not_shiny] miss (for example, Master Ball
          miss-only calibration without saving). *)
  catch_battle : unit -> Pokemon_catch.Catch_runner.outcome;
      (** Catch the wild Pokémon via {!Pokemon_catch.Catch_runner.run}. *)
  finish_catch : Capture.destination -> bool;
      (** Clear post-catch dialogs (nickname NO, Pokédex) back to the overworld.
      *)
}
(** Encounter, visual shiny pre-check, and policy-based catch steps for
    {!game_steps}. *)

type game_steps = {
  catch : Capture_plan.t -> party:int -> Capture.result;
      (** {!Capture.run} on the blind steps, from the overworld (used when
          [policy_catch] is [None]). *)
  policy_catch : policy_catch_steps option;
      (** Optional visual shiny check and {!Pokemon_catch.Catch_runner} path.
          When [Some _], replaces [catch]. *)
  shiny_at : int -> bool;  (** The party member in this slot shows the star. *)
  log : string -> unit;  (** Writes a line to the run log. *)
  show_counters : Wire.Watch.counter list -> unit;
      (** Publishes live [watch.counters] updates to the watch page. *)
}
(** Reads and inputs supplied to {!run}. *)

(** How the action ended. *)
type end_ =
  | Shiny  (** Caught, and its summary shows the star. *)
  | Not_shiny  (** Caught, but no star: the RNG missed its target. *)
  | Not_shiny_intro
      (** Visual battle-intro detector classified the encounter as non-shiny;
          catch turns and Luxury/Ultra Balls were skipped. *)
  | Catch_paused of string
      (** {!Pokemon_catch.Catch_runner} paused safely for user takeover. *)
  | Capture_ended of Capture.end_  (** Anything other than [All_caught]. *)
  | Party_full  (** No slot for the catch, found before the first press. *)

type result = {
  end_ : end_;  (** Terminal outcome of the action. *)
  capture : Capture.result option;
      (** [None] when the capture never ran or ended before catching. *)
}
(** The action's end and the capture's own result. *)

val watch_counters :
  attempt:int -> total:int -> phase:string -> Wire.Watch.counter list
(** Builds the standard [attempt] ([current/total]) and [phase] counter items
    for [watch.counters]. Shared with {!Wild_rng_steps} and {!Gift_rng}. *)

val run : game_steps -> Capture_plan.t -> party:int -> result
(** From the overworld with [party] members. *)

val failure_code : end_ -> string option
(** [None] for [Shiny]; else ["wild_rng_not_shiny"],
    ["wild_rng_not_shiny_intro"], ["wild_rng_catch_paused"],
    ["wild_rng_<capture end>"], or ["wild_rng_party_full"]. *)

val message : result -> string
(** One line for the run log saying how the action ended. *)
