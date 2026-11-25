(** The text speed set to fast through the main menu's options, the plan's
    [set_text_speed_fast]: ported from PokemonLZA_AutoStoryScenes.cpp. Blind but
    for the first menu's tutorial card and the way back: X, 2 s; A on the
    tutorial card (at most 3 pages, 1.5 s after each); then L, Up, A, Down,
    Right (each held 100 ms); then B every second until the overworld is free on
    two reads in a row (read every 250 ms, 30 s at most, [text_speed_timeout]).
*)

val run : Story_steps.game_steps -> Story_steps.outcome
