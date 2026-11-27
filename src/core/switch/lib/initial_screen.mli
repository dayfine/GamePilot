(** Fast initial-screen check for Switch programs and [--preflight].

    Before a Switch program attempts a soft reset or starts its first step,
    {!check} subscribes to {!Home_screen} and {!Black_screen} probes, reads one
    frame (without pressing any button), and classifies what is on screen: a
    black or asleep screen, the Switch HOME menu (lit or dimmed), the user
    select screen, a game screen, or no frame at all.

    On a black screen or missing frame, {!check} fails fast with an immediate
    error instead of retrying soft resets. Otherwise, what happens next follows
    the caller's {!expectation}: fail fast on HOME or user select without
    pressing anything ({!In_game_read_only}, used by [--preflight]); verify or
    resume the target game via {!Console_park} ({!In_game_or_resume} — when a
    tile colour is given, HOME/user select resumes directly, and an unknown
    non-HOME screen presses HOME via {!Console_park.park} first to verify the
    target game's tile before {!Console_park.resume}); or proceed as is for
    programs that start on HOME ({!In_game_or_home}). *)

(** What the Switch screen shows when a program starts. *)
type screen =
  | Black
      (** A black or flat-dark picture ({!Home_screen.black} or
          {!Black_screen.shown}): the console appears asleep, off, or the
          capture card shows a black screen. *)
  | Home of { cursor : int option; game_tile : int option }
      (** The Switch HOME menu (lit), with the cursor slot and the target game's
          tile slot among the four visible tiles when known. *)
  | Home_dimmed  (** The Switch HOME menu, dimmed after sitting idle. *)
  | User_select  (** The Switch "Who is using the software?" screen. *)
  | In_game
      (** Neither black nor a Switch system menu: a game (or another screen). *)
  | No_frame  (** No frame arrived from the daemon within the read timeout. *)

(** What screen a Switch program expects when it starts. *)
type expectation =
  | In_game_read_only
      (** Must already be in a game; fail fast on black, no frame, HOME, dimmed
          HOME, or user select without pressing any button. *)
  | In_game_or_resume of Home_screen.tile_color option
      (** Must be in the target game; fail fast on black or no frame. When a
          tile colour is given: on HOME, dimmed HOME, or user select, resume or
          launch the target game via {!Console_park.resume}; on {!In_game} (any
          non-HOME screen, which might be a different game or Switch Album),
          press HOME via {!Console_park.park} to verify/select the target game's
          tile and then {!Console_park.resume}. When [None]: accept {!In_game}
          without pressing buttons and fail fast on HOME, dimmed HOME, or user
          select. *)
  | In_game_or_home
      (** May start either in the game or on HOME / user select (e.g. programs
          that navigate from HOME themselves); fail fast on black or no frame.
      *)

val classify : Effects.measurements -> screen
(** Classifies one frame's {!Home_screen} and {!Black_screen} measurements. *)

val read : picture:Wire.box -> ?tile:Home_screen.tile_color -> unit -> screen
(** Subscribes to {!Home_screen} and {!Black_screen} probes over [picture],
    waits briefly for a frame, and returns {!classify} of that frame (or
    {!No_frame} on timeout). Strictly read-only: presses nothing. *)

val check :
  log:(string -> unit) ->
  picture:Wire.box ->
  expectation ->
  (unit, string) result
(** Reads the current screen via {!read}, logs it, and checks it against
    [expectation]. Returns [Ok ()] when the console is ready for the program,
    else [Error reason] explaining what screen the console is on. *)

val screen_to_string : screen -> string
(** Human-readable description of a {!screen} reading, for logs and errors. *)
