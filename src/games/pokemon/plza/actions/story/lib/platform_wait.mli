(** The platform at the station, where the opening ends and 01.01 starts:
    [wait_for_platform] and [opening_to_platform] of
    PokemonLZA_AutoStoryScenes.cpp ([plza/lean]), with their timings. *)

val wait_for_platform :
  Story_steps.game_steps -> timeout_ms:int -> Story_steps.outcome
(** The platform's controls hint ({!Story_look.platform_hint}) on two reads in a
    row, read every 300 ms; [platform_not_seen] after [timeout_ms]. *)

val opening_to_platform :
  Story_steps.game_steps -> timeout_ms:int -> Story_steps.outcome
(** From the new game's confirm to the platform: every 300 ms, A on text that
    waits for it (once per text), and Start (the Switch's +) held 2 s to skip
    the opening 750 ms after each fade in, when no text or controls hint shows;
    until the autosave badge shows; then {!wait_for_platform} with the time
    left. [platform_not_seen] when no badge shows in [timeout_ms]. *)

val cutscene_skip_hold_ms : int
(** 2000: how long + is held to skip a cutscene (CUTSCENE_SKIP_HOLD). *)
