(** Action: watches a BDSP battle opening and classifies whether the wild
    Pokémon is shiny from visual dialog-gap timing.

    Ported from the fork's
    [SerialPrograms/Source/PokemonBDSP/Inference/ShinyDetection/PokemonBDSP_ShinyEncounterDetector.cpp]
    (https://github.com/PokemonAutomation/Arduino-Source/blob/main/SerialPrograms/Source/PokemonBDSP/Inference/ShinyDetection/PokemonBDSP_ShinyEncounterDetector.cpp).

    Difference from the fork: GamePilot's daemon is video-only, so detection
    uses visual battle-dialog timing via {!Bdsp_readers.Shiny_encounter_reader}
    with no audio detector. Weather-ability banners (such as Kyogre's Drizzle
    and Groudon's Drought) are waited out until the battle menu appears. *)

val default_timeout_ms : int
(** Default maximum time in ms to wait for the battle menu (30000 ms). *)

val detect :
  picture:Wire.box ->
  ?timeout_ms:int ->
  ?thresholds:Bdsp_readers.Shiny_encounter_reader.thresholds ->
  unit ->
  Bdsp_readers.Shiny_encounter_reader.reading
(** Subscribes the battle menu and battle dialog probes, watches frames until
    the battle menu appears or [timeout_ms] elapses, and returns the classified
    {!Bdsp_readers.Shiny_encounter_reader.reading}. *)
