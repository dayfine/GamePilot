(** Reader: watches an FRLG wild battle opening and classifies whether the wild
    Pokémon is shiny from visual battle-intro timing.

    GamePilot's own reader (modeled on BDSP's
    [Bdsp_readers.Shiny_encounter_detector]). Subscribes
    {!Shiny_encounter_reader.probes} via {!Effects.with_probes}, advances
    {!Shiny_encounter_reader.step} on each frame until the wild intro completes
    or [timeout_ms] elapses, and returns the classified
    {!Shiny_encounter_reader.reading}. *)

val default_timeout_ms : int
(** Default maximum time in ms to wait for the wild intro to complete (15000
    ms). *)

val detect :
  ?timeout_ms:int ->
  ?thresholds:Shiny_encounter_reader.thresholds ->
  unit ->
  Shiny_encounter_reader.reading
(** Subscribes {!Shiny_encounter_reader.probes}, watches frames until the wild
    intro completes or [timeout_ms] elapses, and returns the classified
    {!Shiny_encounter_reader.reading}. *)
