(** Where a line of text sits on an FRLG screen, in game pixels (240x160).
    Measured on Switch captures by matching drawn words (the fork's
    CommandLineTests images); the game draws the same pixels on every backend.
*)

type t = {
  id : string;  (** names the line in probe ids, e.g. ["bag.2"] *)
  left : int;  (** x of the first glyph's left edge *)
  glyph_top : int;  (** y of the glyphs' top row (row 0 of the font cell) *)
  indent : int;
      (** blank columns the template keeps left of the text: on a row that shows
          other text there (the TM case's CLOSE), nothing matches *)
  width : int;
      (** the template's width from [left - indent]: the name column, blank
          included, so a short word does not match a longer one's start *)
}

val bag_row : int -> t
(** Row [i] (0..5) of a bag pocket's list: item names and CANCEL. *)

val tm_case_row : int -> t
(** Row [i] (0..4) of the TM case list: the move name after "No03 ". The CLOSE
    row starts further left and matches nothing here. *)

val summary_move : int -> t
(** Move [i] (0..3) on the summary's KNOWN MOVES page; row 4 is the move offered
    on the list a battle opens to forget a move from (the same 28-pixel pitch,
    pokefirered pokemon_summary_screen.c). *)

val summary_species : t
(** The species on the summary's POKéMON INFO page (page 1), right of NAME:
    pokefirered pokemon_summary_screen.c, [PrintInfoPage], at (47, 19) in the
    right pane's window (15 tiles from the left, 2 from the top). Placed from
    the source and read right on mGBA (each member of mg-02's start,
    2026-11-23). *)

val digit_width : int
(** Every digit of the normal font is 6 pixels wide. *)

val trainer_card_money_digit : int -> t
(** Digit [k] of the money on the Trainer Card's front, counted from the right
    (0: ones): pokefirered trainer_card.c, [PrintMoneyOnCard], right-aligns
    ["¥<money>"] to end at x 136 of window 1 (at (8, 8)), at y 56. Read right on
    mGBA ($25,014 and $29,114, 2026-11-23). *)

val bag_message_digit : int -> t
(** Digit [k] (from the left) of the bag message's second line, where the Coin
    Case's ["Your COINS:\n<coins>"] (pokefirered strings.c [gText_CoinCase],
    item_use.c [FieldUseFunc_CoinCase], left-aligned) prints its count: the
    message window 5 of bag.c at (16, 120), the second line's glyphs at y 137.
    Read right on mGBA (20 coins, 2026-11-23). *)

(** {1 Template rows and the probe box} *)

val template_top : int
(** The first glyph row a template keeps: row 0 is blank in every glyph. *)

val template_height : int
(** Rows kept: down to the shadow under descenders, above the next line's window
    decorations (the bag's dashed separators). *)

val slack : int
(** Game pixels the probe box extends past the template on each side, for a
    capture that is off by a pixel. *)

val box : t -> Wire.box
(** The probe box, normalized to the game picture. *)
