(** Mable's research reward in her office (03.11): the fork's
    [claim_research_reward] (PokemonLZA_AutoStoryConsoleActions.cpp), with
    [overworld_to_main_menu] (PokemonLZA_MenuNavigation.cpp) and
    [press_b_out_of_menu] (PokemonLZA_AutoStoryScenes.cpp), [plza/lean].

    The main menu: the screen is watched up to 30 s for the overworld (the party
    bar) or the main menu ({!Story_look.t.main_menu}), each held 250 ms; 100 ms
    after, the overworld presses X (160 ms, released 240) and watches again, the
    menu ends it; 120 s in all. Mable's Research is three rows down (Down 160
    ms, released 400, three times); A (160 ms, released 2840) opens it on
    Rewards under her lines, passed with A (quiet 3 s, 60 s at most). Then B
    (160 ms, released 840) until the party bar or a text box shows, 60 at most.

    Failures: [main_menu_not_reached] (nothing read in 30 s, or 120 s without
    the menu), [reward_lines_endless] (the lines did not end in 60 s),
    [no_reward_lines] (no line at all: not in her office), [menu_not_closed] (60
    B), and [game_not_running] on the HOME menu.

    Where it differs: the fork's overworld is the party bar's D-pad markers
    ([OverworldPartySelectionWatcher]); here the party bar as the story reads
    it, the markers or its empty last slot ({!Plza_readers.Party_bar}). The fork
    also presses B out of the box system, which nothing reads here. *)

val run : Story_steps.game_steps -> Story_steps.outcome
