(** A story battle fought to its end: the plan's [story_battle]. Ported from
    PokemonLZA_AutoStoryActionTable.cpp, PokemonLZA_AutoStoryConsoleActions.cpp
    and PokemonLZA_TrainerBattle.cpp, with the fork's default battle AI (the
    most effective move, no plus moves).

    The start: up to 10 s for the battle HUD; each read without it holds ZL 2 s
    ({!Lock_on}), and move symbols under ZL count as the start too
    ([battle_never_started] otherwise). The fight, for 120 s at most
    ([battle_failed]): each round reads the screen; a dialogue box after an
    attack ends the battle; on a dialogue box, or when an attack fails, A (160
    ms, released 400) until the first attack. An attack holds ZL up to 1 s for
    the move symbols; with them, the most effective move's button (top X, left
    Y, right A, bottom B; the first of equals) is pressed 160 ms with ZL still
    held (ZL 800 ms in all, then 200 ms released). Without them, 250 ms
    released, and from the third miss in a row the camera turns left (right
    stick) while ZL is mashed, 1 s.

    The move replaces the watch's ZL hold with no release between (protocol
    v1.15, [cancel] with [then]), as the fork dispatches it over the running
    hold. *)

val run : Story_steps.game_steps -> Story_steps.outcome

val attempt_one_attack : Story_steps.game_steps -> int ref -> bool
(** One attack of the fight (PokemonLZA_TrainerBattle.cpp): ZL held up to 1 s
    for the move symbols, the most effective move pressed as they show. Whether
    a move went. [misses] counts the misses in a row (reset on a move); from the
    third, the camera turns left while ZL is mashed. The catches'
    [weaken_target] keeps its own count ({!Catches}). *)
