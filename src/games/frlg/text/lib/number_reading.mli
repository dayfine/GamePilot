(** A number read digit by digit ({!Line_reading}, the ten digits the
    candidates): each digit's cell of the normal font is 6 pixels wide wherever
    the game prints a number, so a cell holds one digit or none. *)

val digits : string list
(** ["0"] to ["9"]. *)

val read_cells :
  Glyph_table.t -> (int -> Text_lines.t) -> max_cells:int -> string list
(** The digits read in cells 0, 1, ... up to [max_cells], stopping at the first
    cell that shows none. *)

val read_left_aligned :
  Glyph_table.t -> (int -> Text_lines.t) -> max_cells:int -> int option
(** Cell 0 the first (most significant) digit; [None] when it shows none. *)

val read_right_aligned :
  Glyph_table.t -> (int -> Text_lines.t) -> max_cells:int -> int option
(** Cell 0 the last (ones) digit; [None] when it shows none. *)
