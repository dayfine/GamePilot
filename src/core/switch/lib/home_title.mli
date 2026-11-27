(** Reader and walk: which game's tile the cursor is on on the Switch's HOME
    menu, by the title HOME writes over the tile row, and the walk along the row
    to a game's tile. The fork reads the title with OCR (PLZA's
    PokemonLZA_AutoStoryIntroScreens.cpp: the row's cyan text, ending in "za");
    here a [core.template_match@1] probe searches the whole title row for a
    template of part of the game's title, as its cyan ink. The walk is the
    fork's PLZA tile search (PokemonLZA_AutoStoryLaunch.cpp), each caller
    passing its own presses and title check.

    The title is read on the whole frame (the daemon's [native] viewport):
    left-aligned from x 125 while the row has not scrolled, over the selected
    tile once it has (console B, 2026-11-25: "Pokémon: Let's Go, Pikachu!" at x
    1230 to 1815). *)

val window : Wire.box
(** The title row: the whole width, y 206 to 278 of the 1920x1080 frame, so a
    title's capitals (their tops at y 218 to 222) are found 12 pixels above and
    below. *)

val cyan : Wire.color_range
(** The title's cyan, as ink: red under 120, green over 150, blue over 200. *)

val probe : string -> Effects.template_hash -> Wire.probe_spec
(** The probe of that id searching {!window} for the title template, every
    frame. *)

val max_score : float
(** 0.08 for every title so far: Pokémon HOME's "HOME" scores 0.034 at most on
    its title (shifted too), 0.143 at least on others; PLZA's "Legends: Z-A"
    0.038 at most on its title, 0.112 at least on others. *)

val shows : Effects.measurements -> string -> bool
(** The probe scores {!max_score} or less: the cursor is on that game's tile. *)

type game_steps = {
  title_shows : unit -> bool;
      (** The game's title shows over the row now (after the last press). *)
  press : Timed_press.t -> unit;  (** Presses one button and waits it out. *)
  log : string -> unit;  (** Writes a line to the run's log. *)
}
(** What {!find_tile} reads and does on the console. *)

type walk = {
  first : Timed_press.t;  (** HOME: from anywhere to HOME's first tile. *)
  next : Timed_press.t;  (** Right: to the next tile. *)
  tiles : int;  (** Tiles read before giving up. *)
}
(** How {!find_tile} walks HOME's tile row. *)

val find_tile : game_steps -> walk -> name:string -> (int, string) result
(** [first], then the title read on each tile, [next] between two, up to [tiles]
    tiles; the tile (0 the first) whose title shows, the cursor left on it, or
    an error naming [name] and the tiles read. Logs ["<name> is tile <n>."],
    counting from 1. *)
