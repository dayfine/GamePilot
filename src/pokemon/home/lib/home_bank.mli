(** Banking Pokémon from a game's box into Pokémon HOME and saving: stages 4 and
    5 of [plza_claim_and_bank.sh] from the BDSPLab lab tools (console B,
    2026-11-20), from the Switch's HOME menu to it again. Pokémon HOME is opened
    on the game ({!Home_launch}), each move made ({!Box_moves}), then + (100 ms,
    released 1.5 s) and A on "save and quit"; the saving banner must show within
    10 s and then the saved banner or the main menu within 60 s, A (3.5 s) on
    the saved banner; then Pokémon HOME is closed
    ({!Switch_home.Game_entry.close_game}).

    Every check that fails ends with an error before the save, leaving Pokémon
    HOME open and unsaved (closing it from HOME discards the moves). Moving
    anything needs all ten box-number digits' templates ({!Box_view.complete});
    without them the call stops on the boxes having moved nothing.

    Where it differs: the script waited for a white banner, which the saving
    banner also is; here the saving banner (two lines) must show first, and the
    end is one line or the main menu. *)

type templates = {
  home_art : string;  (** Pokémon HOME's tile art, PNG ({!Home_tile}) *)
  home_title : string;  (** its title over the row, PNG ({!Home_tile}) *)
  game_icon : string;  (** the game's icon on HOME's game list, PNG *)
  slash : string;  (** the counter's "/300", PNG *)
  digits : (int * string) list;  (** the counter's digits that have one, PNG *)
}
(** The PNG templates a run uploads to find its way. *)

(** What to do on the boxes. *)
type mode =
  | Look
      (** read the box number and HOME's box, log them, and stop there: nothing
          moved, HOME left open on the boxes *)
  | Bank of Box_moves.t list
      (** make each move in order, then save and close HOME *)

val run :
  log:(string -> unit) ->
  picture:Wire.box ->
  templates ->
  mode ->
  (unit, string) result
(** From the Switch's HOME menu: opens Pokémon HOME on the game, then the
    [mode]'s work on the boxes; an error on the first check that fails, or when
    [picture] is not the native frame. *)
