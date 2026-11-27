(** Parking the Switch on its HOME menu while no program drives it, and resuming
    the game from there: the steps done by hand on console B (2026-11-24). New
    here, no fork code: the fork's own HOME steps (NintendoSwitch_GameEntry)
    close and restart the game, which would lose a run's place.

    HOME's A resumes the suspended game when it still runs (the leftmost tile,
    the one played last) and launches it otherwise, through the user select (A
    on the highlighted user) and the game's boot. The cursor is moved to the
    game's tile first: within the tiles in view, or, when none shows the game
    (the row scrolled, or the game further along), Left a tile at a time (up to
    12, the games HOME holds) and then Right (up to 12), reading HOME after each
    press, until one does. A launch ends at the first picture that is not black
    ({!Home_screen.black}: a game's fade to black between screens counts as
    black too, so it is never taken for the game); the runner's soft reset takes
    the game to its last save from there. *)

type resumed =
  | Already_in_game  (** HOME was not on screen: nothing pressed *)
  | Resumed  (** A on HOME showed the game *)
  | Launched  (** A on HOME showed the user select: the game started anew *)

val park :
  log:(string -> unit) ->
  picture:Wire.box ->
  Home_screen.tile_color ->
  (unit, string) result
(** HOME, then waits for the HOME menu. [picture] is where the game picture sits
    in the frame (the daemon's [hello] viewport). Already on HOME: nothing (a
    HOME press there would resume the game), dimmed or not. On the user select:
    B back to HOME. *)

val park_and_close :
  log:(string -> unit) ->
  picture:Wire.box ->
  ?tile:Home_screen.tile_color ->
  unit ->
  (unit, string) result
(** Returns to the Switch HOME menu ({!park}) and closes the running game
    ({!Game_entry.close_game}). Already on HOME with no game running: succeeds
    after checking for the close-game popup. *)

val resume :
  log:(string -> unit) ->
  picture:Wire.box ->
  Home_screen.tile_color ->
  (resumed, string) result
(** From HOME (or the user select) back to the game, as above. A dimmed HOME
    gets B first (nothing on HOME) to bring the light back. *)

val resumed_to_string : resumed -> string
