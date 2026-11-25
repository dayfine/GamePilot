(** Skipping a cutscene from its opening black fade: [plus_skip_step] of
    PokemonLZA_AutoStoryActionTable.cpp ([plza/lean]). Once the fade ends (read
    every 250 ms, 15 s at most), 2.5 s later + (the wire's [Start]) held 2 s;
    the skip's black fade must show within 5 s after the hold. Fails as
    [fade_not_ended] or [cutscene_not_skipped]. *)

val run : Story_steps.game_steps -> Story_steps.outcome
