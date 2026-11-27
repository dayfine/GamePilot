(** Moving a Pokémon from the game's box to the first empty slot of a HOME box,
    on the box screen with the cursor on HOME's first slot (the left pane keeps
    the L/R box switch).

    The box: the number is read ({!Box_view.number}) and R or L pressed (100 ms,
    released 350) up to 10 times towards it, then 500 ms, 25 rounds at most. The
    slot: the first empty one of the primary boxes in order, then the fallback
    boxes in order when every primary box is full. The move: Down and Right to
    the game's slot (D-pad 80 ms, released 200), Y (350 ms); Down/Up then Left
    to the empty slot, Y (400 ms); Up and Left back to HOME's first slot.

    Each check is an error with nothing more pressed: the game's slot must hold
    a Pokémon, the cursor must read on it before Y and back on HOME's first slot
    after; after the drop the HOME slot must hold it and the game's slot be
    empty. *)

type source = {
  box : int;
      (** 1-based game box (currently box 1 only; multi-box switching is left to
          future game-specific adapters). *)
  row : int;  (** 0-based row in the game's box (0 to 4). *)
  col : int;  (** 0-based column in the game's box (0 to 5). *)
}
(** Where to pick up the Pokémon in the game's boxes. *)

type destination = {
  boxes : int list;  (** Primary HOME boxes to try in order, e.g. [166; 167]. *)
  fallback : int list;
      (** Fallback HOME boxes tried in order when every primary box is full. *)
  order : Box_view.order;  (** The scan order over each HOME box. *)
}
(** Where to deposit the Pokémon in Pokémon HOME. *)

type t = {
  name : string;  (** For log lines, e.g. "Vivillon". *)
  source : source;  (** The slot in the game's box. *)
  destination : destination;  (** The primary and fallback HOME boxes. *)
}
(** One Pokémon to move: from the game's box into the first empty slot of the
    first HOME box (primary, then fallback) that has one. *)

type move_error = {
  message : string;  (** Human-readable reason the move stopped. *)
  holding : bool;
      (** [true] when the failure happened after picking up the Pokémon and
          before confirming it landed; callers must not save HOME in this state.
      *)
}
(** Why a move failed, with whether the cursor may still hold a Pokémon. *)

val cursor_probes : t list -> Wire.probe_spec list
(** The cursor's probes over HOME's first slot and each move's game slot. *)

val home_first : Box_view.slot
(** HOME's box, row 1, column 1: where every move starts and ends. *)

val run : log:(string -> unit) -> t -> (unit, move_error) result
(** One move, from the cursor on {!home_first}. *)
