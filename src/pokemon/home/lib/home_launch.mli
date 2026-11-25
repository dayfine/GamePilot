(** From the Switch's HOME menu to Pokémon HOME's boxes with a game connected:
    stages 4 and 5 of [plza_claim_and_bank.sh] from the BDSPLab lab tools
    (console B, 2026-11-20), its presses and waits.

    Any running game is closed first ({!Switch_home.Game_entry.close_game}: HOME
    cannot connect to a game that runs). Pokémon HOME's tile is found among the
    four in view ({!Home_tile}) and started on it with the first user
    ({!Switch_home.Game_entry.start_game}). Then, until the main menu shows
    ({!Home_menus.main_menu}; 90 s at most): a banner (logging in) is waited
    out, anything else (the title) gets A (100 ms, released 3 s). On the main
    menu, A (3.5 s) opens 寶可夢's game list; the cursor goes to the tile showing
    the game's icon (D-pad 80 ms, released 400) and must read there; A (2 s) and
    A (8 s) connect it; the box screen must show within 30 s more
    ({!Box_view.shown}).

    Where it differs: the script found HOME's tile by OCR of the titles and
    started it with three A presses at fixed waits; it pressed Down once to "the
    game" and only logged its title; here the game's tile is found by its icon
    and the cursor is read on it before A. *)

val probes : game_icon:Effects.template_hash -> Wire.probe_spec list
(** {!Home_menus}'s probes. *)

val to_boxes :
  log:(string -> unit) ->
  picture:Wire.box ->
  home_art:string ->
  game_icon:Effects.template_hash ->
  (unit, string) result
(** [home_art] is the PNG of Pokémon HOME's tile art ({!Home_tile}); the boxes'
    probes must be subscribed. *)
