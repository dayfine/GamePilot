(** Deleting one game's save data from System Settings (console B,
    2026-11-15/25, on a firmware whose Data Management lists Delete Save Data
    last): fixed presses, holds and waits, in two steps so that a person looks
    before anything is deleted. The screens are read by {!Delete_save_screen},
    on the whole frame (the daemon's [native] viewport).

    The game is told by its icon; each game page, the Caution screen and the
    success popup are read before going on, and the steps stop with an error,
    having deleted nothing, when one is not there; after a 3 s wait the red
    button is waited for (up to 5 s more) before Up selects it. *)

type game = { key : string; icon_png : string }
(** The game whose save is deleted: a short key and its icon on its "Delete Save
    Data for <user>" page as PNG bytes, in frame pixels. *)

val to_caution :
  log:(string -> unit) ->
  picture:Wire.box ->
  Home_screen.tile_color ->
  game ->
  (unit, string) result
(** Closes the running game ({!Game_entry.close_game}, [tile_color] for the HOME
    reader), goes from HOME to System Settings > Data Management > Delete Save
    Data, opens each game in the list in turn (up to 6) until one's page shows
    [game]'s icon, backing out of the others, then opens "Delete Save Data for
    <user>" and selects the red Delete Save Data button on the Caution screen.
    Deletes nothing. [Error] (still nothing deleted) when the picture is not the
    whole frame, when no row is the game (left on the list), or when a screen is
    not the one expected. *)

val confirm : log:(string -> unit) -> picture:Wire.box -> (unit, string) result
(** On the Caution screen with the red button selected ({!to_caution}'s end): A
    on it, OK on "Successfully deleted save data.", HOME. [Error] without a
    press when the red button is not showing selected, and after the one A when
    the success popup does not show. *)
