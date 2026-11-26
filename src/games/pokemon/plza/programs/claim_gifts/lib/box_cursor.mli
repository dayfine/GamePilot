(** The Boxes' cursor, moved by counting presses from where the Boxes open it:
    on the open box's first slot (console B, 2026-11-20 to 26). Rows are the
    party (0) and the box's five (1 to 5), six columns each, the party's six
    slots over the box's columns. A move is Up or Down to the row, then Left or
    Right to the column, each 80 ms and released 250, the moves and timings of
    the party gift's move as run on console B (2026-11-25).

    A cell is read by holding the read 1 s within 2 s on the Boxes
    ({!Plza_readers.Box_cell}). A Pokémon is carried with Y (400 ms) on its
    cell, read first as holding one, the moves, and Y (600 ms) on the target,
    read first as empty; a target that does not read empty gets it back where it
    was. Ours, as the fork moves a box's Pokémon by its own cursor reader
    (PokemonLZA_BoxDetection.cpp's BoxDetector); the fork's presses are not
    ported. The probes must be subscribed ({!Mystery_gift.probes}). *)

(** What a cell read. *)
type cell =
  | Filled  (** A Pokémon is there. *)
  | Empty  (** No Pokémon is there. *)
  | Not_read of string  (** Why it was not read, or a Pokémon not carried. *)

type t
(** Where the cursor is: a row and a column. *)

val party_row : int
(** 0. *)

val box_rows : int
(** 5. *)

val columns : int
(** 6. *)

val of_slot : int -> int * int
(** A box slot's row and column: slot 1 is row 1, column 0, slot 7 row 2. *)

val opened : unit -> t
(** The cursor as the Boxes open: row 1, column 0. *)

val position : t -> int * int
(** Its row and column. *)

val go : t -> row:int -> col:int -> unit
(** Pressed to the cell. *)

val read : t -> row:int -> col:int -> cell
(** Pressed to the cell, and the cell read. *)

val carry : t -> from:int * int -> onto:int * int -> cell
(** The Pokémon on [from] carried to [onto] as above; then [onto] read ([Filled]
    when it arrived). [Not_read] when [from] holds none, or [onto] was not empty
    (the Pokémon put back on [from]). *)
