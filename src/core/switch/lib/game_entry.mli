(** Closing the game from HOME and starting one from a HOME tile: a port of the
    fork's NintendoSwitch_GameEntry.cpp (close_game_from_home,
    start_game_from_home_with_inference and move_to_user, the Pro Controller
    paths with video), its steps, waits, order and log lines. HOME, the user
    select and the close-game popup are read by {!Home_screen} and
    {!Close_game_popup}, the launch's black by {!Black_screen}, each over the
    game picture at [picture] (the daemon's [hello] viewport).

    Where it differs, deliberately: a dimmed HOME counts as HOME (the fork has
    none); the fork's open-ended loops are bounded (close 20 rounds, start 10
    rounds of 30 s) and end in an error; the start's update menu, online check
    and failed-to-connect readers are not ported, so those screens fall to the
    30 s "no recognizable state" path (HOME again); the black watcher is read
    while waiting, not during presses; ensure_at_home does not read the console
    type. *)

val close_game :
  log:(string -> unit) ->
  picture:Wire.box ->
  Home_screen.tile_color ->
  (unit, string) result
(** close_game_from_home: from HOME (pressing HOME until it shows), X to close
    the running game, A on the popup, until HOME shows again; "already closed"
    when two tries find no popup. *)

val start_game :
  log:(string -> unit) ->
  picture:Wire.box ->
  game_slot:int ->
  user_slot:int ->
  Home_screen.tile_color ->
  (unit, string) result
(** start_game_from_home_with_inference: B until HOME; with [game_slot] (from 1)
    HOME then Right to that tile (0: the tile the cursor is on); A; then A on
    HOME again, the user ([user_slot], 0 the highlighted one) on the user
    select, until the launch's black. A HOME press with a game running resumes
    it: close the game first. *)
