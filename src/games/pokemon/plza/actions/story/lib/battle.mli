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

    Where it differs: a lost battle, [battle_lost], which does not repeat, so
    the run tries the checkpoint again from the last autosave. The fork reads no
    loss: its fight ran on through the black fade, Urbain's heal ("It's OK! I
    healed up Chikorita!") and Andi's rematch until its 120 s ran out (01.03,
    console B, 2026-11-25). A loss needs evidence: a black fade read while the
    lead's last HP read ([lead_hp] of {!Look.t}, the bar under its level badge)
    is 0.1 or less, about 10% of the bar (1 HP of 19 reads 0.04, and the bar
    stays so while the lead faints, about 5 s before the fade). A black fade
    with the lead healthy, or with no HP read, is a cutscene and the fight goes
    on, as the fork's does: a won battle can fade into the trainer's line
    (03.02b, Totodile beaten: "We're not done just yet!", console B,
    2026-11-25), and that line ends the battle as any dialogue does. So a story
    battle with several phases ends at the first trainer's line after an attack;
    the plan gives each phase its own event. A win with the lead at 10% or less
    that fades is taken for a loss and tried again; a loss whose fade or HP the
    reads miss (once per round, 1.25 s or more apart) takes the heal's line for
    the won battle's, and the next scene fails.

    What follows a loss: before the player has reached a Pokémon Center (01.03,
    Andi), Urbain heals the lead and the battle is fought again in place; later
    in the story a loss sends the player back to a Pokémon Center. Neither is
    followed here: the run tries the checkpoint again from its autosave. A loss
    that ends at a Pokémon Center has no handling (the fork has none):
    follow-up.

    The move replaces the watch's ZL hold with no release between (protocol
    v1.15, [cancel] with [then]), as the fork dispatches it over the running
    hold. *)

val run : Steps.game_steps -> Steps.outcome

val attempt_one_attack : Steps.game_steps -> int ref -> bool
(** One attack of the fight (PokemonLZA_TrainerBattle.cpp): ZL held up to 1 s
    for the move symbols, the most effective move pressed as they show. Whether
    a move went. [misses] counts the misses in a row (reset on a move); from the
    third, the camera turns left while ZL is mashed. The catches'
    [weaken_target] keeps its own count ({!Catches}). *)
