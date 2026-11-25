(** Moving a Pokémon from the game's box to the first empty slot of a HOME box:
    stage 5 of [plza_claim_and_bank.sh] from the BDSPLab lab tools (console B,
    2026-11-20), its [goto_home_box], [empty_rtl] / [empty_ltr] and
    [emit_box_move] with their presses, on the box screen with the cursor on
    HOME's first slot (the left pane keeps the L/R box switch).

    The box: the number is read ({!Box_view.number}) and R or L pressed (100 ms,
    released 350) up to 10 times towards it, then 500 ms, 25 rounds at most. The
    slot: the first empty one of the box in the move's order, or of the next box
    when it is full. The move: Right to the game's slot (D-pad 80 ms, released
    200), Y (350 ms); Down then Left to the empty slot, Y (400 ms); Up and Left
    back to HOME's first slot.

    Where it differs, each check an error with nothing more pressed: the game's
    slot must hold a Pokémon, the cursor must read on it before Y and back on
    HOME's first slot after; after the drop the HOME slot must hold it and the
    game's slot be empty. The script went back to the first slot after the first
    move only; here after every move. *)

type t = {
  name : string;  (** for log lines, e.g. "Vivillon" *)
  game_col : int;
      (** its slot in the game's box: row 1, this column (0-based) *)
  boxes : int list;  (** HOME's boxes to try in order, e.g. [166; 167] *)
  order : Box_view.order;  (** the order the HOME box's slots are tried in *)
}
(** One move: a Pokémon in the game's box and where in HOME it goes. *)

val cursor_probes : t list -> Wire.probe_spec list
(** The cursor's probes over HOME's first slot and each move's game slot. *)

val home_first : Box_view.slot
(** HOME's box, row 1, column 1: where every move starts and ends. *)

val run : log:(string -> unit) -> t -> (unit, string) result
(** One move, from the cursor on {!home_first}. *)
