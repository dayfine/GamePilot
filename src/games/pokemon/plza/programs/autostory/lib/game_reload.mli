(** Back to PLZA's latest autosave, as PokemonLZA_AutoStoryConsoleBackend.cpp
    reloads it, with the opened game to its menu of NintendoSwitch_GameEntry.cpp
    and the game menu into the game of PokemonLZA_GameEntry.cpp. The game is
    closed from HOME and started from HOME's first tile
    ({!Switch_home.Game_entry}); the loading black must show and go
    ({!Plza_readers.Game_loading}, 40 s each); then A is mashed 2 s until the
    entering black shows (60 s at most), with B on a blue dialog
    ({!Plza_readers.Dialog_box.blue_shown}) and A on the backup save's arrow
    ({!Plza_readers.Choice_arrow.backup_save_shown}), each followed by the mash
    again; the black must go within 60 s more; then 1 s.

    Where it differs: the fork finds PLZA's tile among HOME's first 8 by OCR;
    here it is the first tile (the game just closed was played last). The fork's
    title loop has no bound; here 10 rounds, then an error. No frame of the
    title, its dialog or the backup save's arrow is tested yet. *)

val tile_color : Switch_home.Home_screen.tile_color
(** {!Plza_readers.Switch_home_tile.tile_color}. *)

val reload : log:(string -> unit) -> picture:Wire.box -> (unit, string) result
(** In the effect context, with {!Live_story_screen.probes} subscribed. *)
