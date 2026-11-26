(** Reader: Pokémon HOME's box screen, a game connected: HOME's box on the left,
    the game's on the right, each six columns by five rows. Measured on console
    B's captures of 2026-11-24 (the BDSP banking run, [test/images]).

    - The box number: the counter under HOME's box ("152/300", dark grey on
      white, left-aligned from x 157, about 17 px a character, y 785 to 808).
      Its "/300" is found by a [core.template_match@1] probe with ink (the
      pixels each channel 170 or under) along (150, 780, 150, 34); a score of
      0.1 or less means the box screen shows (0.018 at most on the boxes,
      shifted too; 0.273 at least elsewhere). The digits before it (as many as
      fit from x 153 to the slash, 17 px each) are each read by one probe per
      digit template in a 26 px window, the lowest score, 0.08 or less (the
      right digit 0.038 at most, the next best 0.102 at least, an 8 against a 3;
      boxes 152, 158, 159, 164 and 167, shifted too). The digits are cut from
      those captures: the ink's columns (170 or under) and 2 px each side, y 783
      to 810. The lab script ([plza_claim_and_bank.sh] in the BDSPLab lab tools)
      read the counter with tesseract; there is no OCR here, so every digit
      needs a template, and the steps refuse to move anything until all ten are
      there ({!complete}).
    - A slot (the script's [empty_rtl] / [empty_ltr] boxes): 56 px round (1920 ×
      (0.073 + 0.0725 col), 1080 × (0.228 + 0.112 row)) on the left, from 1920 ×
      0.5635 on the right. Empty is flat and light: its stddevs summing to 25 or
      less and its mean to 550 or more. Empty slots read 20 at most, shifted
      too; the palest Pokémon, Mew, which the script's dark-pixel test took for
      empty, 42 (29.5 brightened by 1.1, its whites clipped).
    - The cursor: the green arrow (green over 150 and over red and blue by 60)
      over a slot, which bobs: (cx - 25, cy - 112, 50, 54), 0.15 of it green.
      The tooltip's green underline over a neighbour reads 0.08 at most. *)

(** The two boxes on the screen. *)
type pane =
  | Home_box  (** HOME's box, on the left *)
  | Game_box  (** the game's box, on the right *)

type slot = { pane : pane; row : int; col : int }
(** A slot of a box, row and column 0-based from the top left. *)

val columns : int
(** 6. *)

val slot_rows : int
(** 5. *)

type templates = {
  slash : Effects.template_hash;  (** "/300" *)
  digits : (int * Effects.template_hash) list;  (** the digits with one *)
}
(** The box counter's uploaded templates. *)

val complete : templates -> bool
(** All ten digits have a template. *)

val probes : templates -> Wire.probe_spec list
(** The counter's and every slot's probes (the cursor's are {!cursor_probes}).
*)

val cursor_probes : slot -> Wire.probe_spec list
(** The arrow's probe over the slot. *)

val shown : Effects.measurements -> bool
(** The counter's "/300" shows: the box screen. *)

val number : Effects.measurements -> int option
(** HOME's box number; [None] when a digit reads no template. *)

val counter_to_string : Effects.measurements -> string
(** Each digit window's best digit and score, for a log line. *)

val empty : Effects.measurements -> slot -> bool
(** The slot reads empty. *)

val occupied : Effects.measurements -> slot -> bool
(** Neither empty nor unread. *)

val cursor_at : Effects.measurements -> slot -> bool
(** The cursor's arrow shows over the slot. *)

(** The script's scan orders over HOME's box: column by column, top to bottom in
    each. *)
type order =
  | Right_to_left  (** the rightmost column first *)
  | Left_to_right  (** the leftmost column first *)

val first_empty : Effects.measurements -> order -> slot option
(** The first empty slot of HOME's box in that order. *)

val slot_to_string : slot -> string
(** "HOME's box row 4 column 4", "the game's box row 1 column 1". *)

val place_to_string : slot -> string
(** "row 4 column 4". *)
