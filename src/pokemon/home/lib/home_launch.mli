(** From the Switch's HOME menu to Pokémon HOME's boxes with a game connected.

    Any running game is closed first ({!Switch_home.Game_entry.close_game}: HOME
    cannot connect to a game that runs). Pokémon HOME's tile is found by
    {!Switch_home.Home_title.find_tile}: HOME (100 ms, released 1 s) to the
    first tile, then Right (80 ms, released 600) along the row, up to 8 tiles,
    each read for its title for 1.5 s ({!Home_tile.on_home_tile}); it is started
    where the cursor stopped, with the first user
    ({!Switch_home.Game_entry.start_game}). Then, until the main menu shows
    ({!Home_menus.main_menu}; 90 s at most): a banner (logging in) is waited
    out, anything else (the title) gets A (100 ms, released 3 s). On the main
    menu, A (3.5 s) opens 寶可夢's game list; the cursor goes to the tile showing
    the game's icon (D-pad 80 ms, released 400) and must read there; A (2 s) and
    A (8 s) connect it; the box screen must show within 30 s more
    ({!Box_view.shown}). *)

val to_boxes :
  log:(string -> unit) ->
  picture:Wire.box ->
  home_art:string ->
  home_title:string ->
  game_icon:Effects.template_hash ->
  (unit, string) result
(** [home_art] and [home_title] are the PNGs of Pokémon HOME's tile art and
    title ({!Home_tile}); the boxes' probes must be subscribed. *)
