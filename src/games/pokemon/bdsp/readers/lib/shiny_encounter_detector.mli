(** Reader: watches a BDSP battle opening and classifies whether the wild
    Pokémon is shiny from visual dialog-gap timing.

    Ported from upstream
    {{:https://github.com/PokemonAutomation/Arduino-Source/blob/main/SerialPrograms/Source/PokemonBDSP/Inference/ShinyDetection/PokemonBDSP_ShinyEncounterDetector.h}PokemonBDSP_ShinyEncounterDetector.h}
    and
    {{:https://github.com/PokemonAutomation/Arduino-Source/blob/main/SerialPrograms/Source/PokemonBDSP/Inference/ShinyDetection/PokemonBDSP_ShinyEncounterDetector.cpp}PokemonBDSP_ShinyEncounterDetector.cpp}.

    Difference from upstream: GamePilot's daemon is video-only, so detection
    uses visual battle-dialog timing via {!Shiny_encounter_reader} with no audio
    detector. Weather-ability banners (such as Kyogre's Drizzle and Groudon's
    Drought) are waited out until the battle menu appears. *)

val default_timeout_ms : int
(** Default maximum time in ms to wait for the battle menu (30000 ms). *)

val detect :
  picture:Wire.box ->
  ?timeout_ms:int ->
  ?thresholds:Shiny_encounter_reader.thresholds ->
  unit ->
  Shiny_encounter_reader.reading
(** Subscribes the battle menu and battle dialog probes, watches frames until
    the battle menu appears or [timeout_ms] elapses, and returns the classified
    {!Shiny_encounter_reader.reading}. *)
