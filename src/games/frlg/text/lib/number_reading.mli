(** A number read digit by digit ({!Line_reading}, the ten digits the
    candidates): each digit's cell is as wide as the font's digits (6 pixels in
    the normal font, 5 in the small one) wherever the game prints a number, so a
    cell holds one digit or none. *)

val digits : string list
(** ["0"] to ["9"]. *)

val small_max_score : float
(** The highest score a small-font digit may read with: 0.04. Its templates are
    small (5 by 12 pixels), so a pixel is worth more: right digits score 0 on
    mGBA and up to 0.027 on Switch captures (seams of the scale), the best wrong
    digit 0.033 on mGBA and 0.049 on Switch. The normal font keeps
    {!Line_reading.max_score}. *)

val read_cells :
  ?max_score:float ->
  Glyph_table.t ->
  (int -> Text_lines.t) ->
  max_cells:int ->
  string list
(** The digits read in cells 0, 1, ... up to [max_cells], stopping at the first
    cell that shows none. *)

val read_left_aligned :
  ?max_score:float ->
  Glyph_table.t ->
  (int -> Text_lines.t) ->
  max_cells:int ->
  int option
(** Cell 0 the first (most significant) digit; [None] when it shows none. *)

val read_right_aligned :
  ?max_score:float ->
  Glyph_table.t ->
  (int -> Text_lines.t) ->
  max_cells:int ->
  int option
(** Cell 0 the last (ones) digit; [None] when it shows none. *)
