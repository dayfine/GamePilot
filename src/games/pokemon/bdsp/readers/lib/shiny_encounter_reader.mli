(** Pure visual-only state machine for BDSP battle-intro shiny detection.

    Ported from upstream
    {{:https://github.com/PokemonAutomation/Arduino-Source/blob/main/SerialPrograms/Source/VideoGames/PokemonSwSh/Inference/Battles/PokemonSwSh_BattleDialogTracker.h}PokemonSwSh_BattleDialogTracker.h},
    {{:https://github.com/PokemonAutomation/Arduino-Source/blob/main/SerialPrograms/Source/VideoGames/PokemonSwSh/Inference/Battles/PokemonSwSh_BattleDialogTracker.cpp}PokemonSwSh_BattleDialogTracker.cpp},
    {{:https://github.com/PokemonAutomation/Arduino-Source/blob/main/SerialPrograms/Source/PokemonBDSP/Inference/ShinyDetection/PokemonBDSP_ShinyEncounterDetector.h}PokemonBDSP_ShinyEncounterDetector.h},
    and
    {{:https://github.com/PokemonAutomation/Arduino-Source/blob/main/SerialPrograms/Source/PokemonBDSP/Inference/ShinyDetection/PokemonBDSP_ShinyEncounterDetector.cpp}PokemonBDSP_ShinyEncounterDetector.cpp}.

    Difference from the fork: GamePilot's daemon is video-only, so this module
    uses dialog-gap timing alone with no audio detector and no per-frame
    sparkle-template aggregator. It therefore reports [Shiny] (rather than
    distinguishing star vs. square sparkles) when the wild-animation gap falls
    within the shiny timing window.

    Weather-ability banners such as Kyogre's Drizzle ("It started to rain!") and
    Groudon's Drought ("The sunlight turned harsh!") appear as battle dialogs
    after the player send-out animation (or immediately after the wild
    animation). The first dialog-on edge after the wild animation ends closes
    the wild-animation timing window, and any subsequent post-entry weather or
    ability dialogs remain in [Post_entry] until the battle menu appears, so
    weather banners never corrupt the wild-animation duration. *)

(** Phase of a BDSP battle opening tracked from dialog transitions. *)
type phase =
  | Before_anything
      (** Waiting for the opening wild-appearance battle dialog. *)
  | Wild_animation
      (** Wild Pokémon cry and optional shiny sparkle animation after the first
          dialog clears. *)
  | Your_animation
      (** Player send-out animation after the second dialog clears. *)
  | Post_entry
      (** Post-entry weather or ability dialogs (such as Drizzle or Drought)
          before the battle menu appears. *)

(** Visual-only shiny verdict for the wild encounter. *)
type verdict =
  | Shiny  (** Wild-animation dialog gap fell within the shiny delay window. *)
  | Not_shiny
      (** Battle menu reached with a wild-animation gap outside the shiny delay
          window. *)
  | Unknown
      (** Battle menu was not reached or no wild-animation gap was measured. *)

type thresholds = {
  shiny_delay_ms : float;
      (** Expected wild-animation duration in ms when shiny (default 3900). *)
  min_margin_ms : float;
      (** Allowed margin below [shiny_delay_ms] in ms (default 300). *)
  max_margin_ms : float;
      (** Allowed margin above [shiny_delay_ms] in ms (default 500). *)
}
(** Timing window for classifying the wild-animation dialog gap. *)

type reading = {
  verdict : verdict;  (** Classified shiny verdict for the wild encounter. *)
  wild_animation_ms : float option;
      (** Measured gap in ms from the first battle dialog clearing to the next
          battle dialog or battle menu appearing. *)
  your_animation_ms : float option;
      (** Measured gap in ms from the second battle dialog clearing to the next
          battle dialog or battle menu appearing. *)
  phase : phase;  (** Encounter phase reached when watching ended. *)
}
(** Summary produced once the battle menu is reached or watching times out. *)

type state
(** Mutable-free tracker state advanced one frame at a time by {!step}. *)

val default_thresholds : thresholds
(** Upstream BDSP timing window: 3900 ms (-300 / +500 ms, i.e. 3600..4400 ms).
*)

val probes : picture:Wire.box -> Wire.probe_spec list
(** Combined probes for {!Battle_detector} and {!Battle_dialog_detector}. *)

val init : state
(** Fresh tracker state in {!Before_anything} with no dialog seen yet. *)

val is_finished : state -> bool
(** [true] once the battle menu has been observed. *)

val step_signals :
  t_ms:float -> battle_menu:bool -> dialog_on:bool -> state -> state
(** Advances [state] from pre-evaluated boolean signals at timestamp [t_ms]. *)

val step : frame:Effects.measurements -> state -> state
(** Advances [state] from one probe frame using {!Battle_detector.shown} and
    {!Battle_dialog_detector.shown}. *)

val classify : ?thresholds:thresholds -> state -> reading
(** Classifies [state] into a {!reading} using [thresholds] (defaults to
    {!default_thresholds}). *)

val verdict_to_string : verdict -> string
(** Short lowercase name of a verdict ([shiny], [not_shiny], [unknown]). *)

val format_reading : reading -> string
(** One-line human-readable summary of a {!reading} for logs. *)
