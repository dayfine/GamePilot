(** Reader: the Switch's HOME menu and the user select a launch shows, told from
    a game's picture. Ported from the fork's NintendoSwitch_HomeMenuDetector.cpp
    and NintendoSwitch_StartGameUserSelectDetector.cpp
    (StartGameUserSelectDetector_Switch1, console B's), with their boxes and
    thresholds.

    Where it differs: the daemon's probe boxes lie inside the game picture (the
    fork's FRLG GAME_BOX, daemon/src/viewport.h), so each of the fork's
    whole-frame boxes is clipped to it, and the HOME detector's user icon box,
    outside the picture, is left out. New here: which tile the cursor is on (its
    cyan frame, above the tile) and which tile shows a game's colour (the first
    four tiles; the leftmost is the game played last), and the dark theme's HOME
    dimmed (its grey at about a sixth). Measured on console B's captures in
    [test/images] (2026-11-24). *)

type tile_color = { min : int * int * int; max : int * int * int }
(** The colour range most of a game's tile art is in. *)

type t =
  | Home of { cursor : int option; game_tile : int option }
      (** The HOME menu: the tile the cursor is on and the first tile showing
          the game's colour, each 0-based from the left, when one does. *)
  | Home_dimmed
      (** The HOME menu, dimmed after a while untouched: too dark to read its
          cursor and tiles. Any press brings the light back. *)
  | User_select  (** "Who is using the software?" *)
  | Elsewhere  (** Neither: the game, or a screen on the way to it. *)

val tiles : int
(** 4: the tiles read, from the left. *)

val probes : tile_color -> Wire.probe_spec list
(** The probes [read] needs, the game's tile colour among them. *)

val read : Effects.measurements -> t
(** [Elsewhere] also when a probe is missing. *)

val black : Effects.measurements -> bool
(** The whole picture is black (a launch's loading screen). *)

val to_string : t -> string
