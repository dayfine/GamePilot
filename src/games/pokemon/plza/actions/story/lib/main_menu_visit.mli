(** The game's main menu (X) opened from the overworld and closed again, as
    Mable's reward does (03.15, {!Mable_reward}): ported from
    PokemonLZA_MenuNavigation.cpp (the way to the menu) and
    PokemonLZA_AutoStoryScenes.cpp (B out of it), through
    PokemonLZA_AutoStoryConsoleActions.cpp. Also the way to read the menu's Link
    Play row (the [mystery_gift] story flag, [Story_flag_read]).

    Opening: the screen is watched up to 30 s for the overworld (the party bar)
    or the main menu ({!Look.t.main_menu}), each held 250 ms; 100 ms after, the
    overworld presses X (160 ms, released 240) and watches again, the menu ends
    it; 120 s in all. Closing: B (160 ms, released 840) until the party bar or a
    text box shows, 60 at most.

    Failures: [main_menu_not_reached] (nothing read in 30 s, or 120 s without
    the menu), [menu_not_closed] (60 B), and [game_not_running] on the HOME
    menu.

    Where it differs: the fork's overworld is the party bar's D-pad markers (its
    overworld party selection watcher); here the party bar as the story reads
    it, the markers or its empty last slot ({!Plza_readers.Party_bar}). The fork
    also presses B out of the box system, which nothing reads here. *)

val enter : Steps.game_steps -> log:(string -> unit) -> Steps.outcome
(** The main menu open, as above; [log] gets ["overworld: X"] at each X and
    ["main menu"] once it shows. *)

val leave : Steps.game_steps -> Steps.outcome
(** B out of the menu until the party bar or a text box shows, as above. *)
