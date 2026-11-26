(** Banking Pokémon from a game's box into Pokémon HOME and saving, from the
    Switch's HOME menu to it again. Pokémon HOME is opened on the game
    ({!Home_launch}), each move made ({!Box_moves}), then + (100 ms, released
    1.5 s) and A on "save and quit"; the saving banner must show within 10 s and
    then the saved banner or the main menu within 60 s, A (3.5 s) on the saved
    banner; then Pokémon HOME is closed ({!Switch_home.Game_entry.close_game}).

    How a mid-batch failure is handled is chosen by {!on_failure}: leave HOME
    open unsaved ({!Stop_open}), close HOME without saving ({!Quit_discard}), or
    save already-completed moves and close HOME ({!Save_partial}, which never
    saves if the cursor may be holding a Pokémon). Moving anything needs all ten
    box-number digits' templates ({!Box_view.complete}); without them the call
    stops on the boxes having moved nothing. *)

type templates = {
  home_art : string;  (** Pokémon HOME's tile art, PNG ({!Home_tile}) *)
  home_title : string;  (** its title over the row, PNG ({!Home_tile}) *)
  game_icon : string;  (** the game's icon on HOME's game list, PNG *)
  slash : string;  (** the counter's "/300", PNG *)
  digits : (int * string) list;  (** the counter's digits that have one, PNG *)
}
(** The PNG templates a run uploads to find its way. *)

(** What to do when a move fails mid-batch. *)
type on_failure =
  | Stop_open
      (** Stop immediately and leave Pokémon HOME open, unsaved (the default).
      *)
  | Quit_discard
      (** Stop immediately and close Pokémon HOME without saving, discarding any
          moves made so far. *)
  | Save_partial
      (** Stop immediately; if at least one Pokémon was moved and the cursor is
          not holding a Pokémon, save and close HOME. If nothing was moved,
          close without saving. If the cursor may hold a Pokémon, leave HOME
          open unsaved. *)

type deposit = {
  moves : Box_moves.t list;  (** The moves to perform in order. *)
  on_failure : on_failure;  (** Failure contract for the batch. *)
}
(** One banking batch. *)

(** What to do on the boxes. *)
type mode =
  | Look
      (** Read the box number and HOME's box, log them, and stop there: nothing
          moved, HOME left open on the boxes. *)
  | Bank of deposit  (** Make each move in order under its failure contract. *)

type game_steps = {
  move : Box_moves.t -> (unit, Box_moves.move_error) result;
      (** Perform one move from the game's box to HOME. *)
  save : unit -> (unit, string) result;  (** Save and exit HOME's boxes. *)
  close : unit -> (unit, string) result;  (** Close Pokémon HOME. *)
  log : string -> unit;  (** Log a status line. *)
}
(** The game-facing steps {!run_deposit} drives on the box screen. *)

val run_deposit : game_steps -> deposit -> (unit, string) result
(** Run [deposit] through [game_steps], enforcing [deposit.on_failure]. *)

val run :
  log:(string -> unit) ->
  picture:Wire.box ->
  templates ->
  mode ->
  (unit, string) result
(** From the Switch's HOME menu: opens Pokémon HOME on the game, then runs
    [mode] on the boxes; returns [Error] when a check fails or [picture] is not
    the native frame. *)
