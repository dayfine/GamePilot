(** Back to PLZA's latest autosave: [reload_latest_save]
    (PokemonLZA_AutoStoryConsoleBackend.cpp, [plza/lean]) with
    [openedgame_to_gamemenu] (NintendoSwitch_GameEntry.cpp) and
    [gamemenu_to_ingame] (PokemonLZA_GameEntry.cpp). The game is closed from
    HOME and started from HOME's first tile ({!Switch_home.Game_entry}); the
    loading black must show and go ({!Plza_readers.Game_loading}, 40 s each);
    then A is mashed 2 s and the entering black must show within 60 s and go
    within 60 s more; then 1 s.

    Where it differs: the fork finds PLZA's tile among HOME's first 8 by OCR;
    here it is the first tile (the game just closed was played last). The
    title's dialog (B) and backup-save arrow (A) watchers of
    [gamemenu_to_ingame] are not ported: either screen times the entry out. *)

val tile_color : Switch_home.Home_screen.tile_color
(** PLZA's tile colour for the HOME reader. A guess, not measured: the HOME
    reader's cursor and HOME detection do not need it. *)

val reload : log:(string -> unit) -> picture:Wire.box -> (unit, string) result
(** In the effect context, with {!Live_story_screen.probes} subscribed. *)
