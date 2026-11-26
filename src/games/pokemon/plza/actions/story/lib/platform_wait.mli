(** The platform at the station, where the opening ends and 02-platform-to-plaza
    starts: ported from PokemonLZA_AutoStoryScenes.cpp, with its timings. *)

val wait_for_platform : Steps.game_steps -> timeout_ms:int -> Steps.outcome
(** The platform's controls hint ({!Look.platform_hint}) on two reads in a row,
    read every 300 ms; [platform_not_seen] after [timeout_ms]. *)

val opening_to_platform : Steps.game_steps -> timeout_ms:int -> Steps.outcome
(** From the new game's confirm to the platform: every 300 ms, A on text that
    waits for it (once per text), and + ([Plus]) held 2 s to skip the opening
    750 ms after each fade in, when no text or controls hint shows; until the
    autosave badge shows; then {!wait_for_platform} with the time left.
    [platform_not_seen] when no badge shows in [timeout_ms]. *)

val cutscene_skip_hold_ms : int
(** 2000: how long + is held to skip a cutscene. *)
