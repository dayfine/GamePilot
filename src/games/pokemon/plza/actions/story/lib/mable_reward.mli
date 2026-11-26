(** Mable's research reward in her office (03.15): ported from
    PokemonLZA_AutoStoryConsoleActions.cpp, with the way from the overworld to
    the main menu from PokemonLZA_MenuNavigation.cpp and B out of the menu from
    PokemonLZA_AutoStoryScenes.cpp.

    The main menu is opened ({!Main_menu_visit.enter}). Mable's Research is
    three rows down (Down 160 ms, released 400, three times); A (160 ms,
    released 2840) opens it on Rewards under her lines, passed with A (quiet 3
    s, 60 s at most). Then the menu is closed ({!Main_menu_visit.leave}).

    Failures: those of {!Main_menu_visit}, [reward_lines_endless] (the lines did
    not end in 60 s) and [no_reward_lines] (no line at all: not in her office).
*)

val run : Steps.game_steps -> Steps.outcome
(** The reward claimed as above, back on the overworld. *)
