(** Skipping a cutscene from its opening black fade: ported from
    PokemonLZA_AutoStoryActionTable.cpp. Once the fade ends (read every 250 ms,
    15 s at most), 2.5 s later + ([Plus]) held 2 s; the skip's black fade must
    show within 5 s after the hold. Fails as [fade_not_ended] or
    [cutscene_not_skipped]. *)

val run : Steps.game_steps -> Steps.outcome
(** The cutscene skipped, as above. *)
