(** Reader: where the cursor is in the Easy Chat editor's lower panel (the mail
    editor, pokefirered easy_chat_2.c and easy_chat_3.c). Not in the fork, which
    never writes a message. Made from mGBA frames of the ? Mail (Route 4 Pokémon
    Center, 2026-11-25), in GBA pixels:

    - the group grid (A on a field): two columns of group names, four rows shown
      16 apart; the selected group sits in a red rectangle (x 17-98 or 101-182,
      y 88 + 16 row to 103 + 16 row; red (239, 82, 82) and (255, 0, 0)).
      {!group_cell} finds the rectangle by its left edge.
    - the word list (A on a group): two columns of words, four rows shown; a
      dark arrow left of the selected word (x 22-27 or 123-128, it bobs a
      pixel), as the menus' ({!Cursor_column}). {!word_cell} finds it.

    The names and words themselves are read with templates
    ({!Frlg_text.Text_lines.easy_chat_group_cell},
    {!Frlg_text.Text_lines.easy_chat_word_cell}). *)

type cell = { row : int; col : int }
(** A shown row (0..3, top first) and column (0 left, 1 right). *)

val probes : Wire.probe_spec list
(** The group rectangle's eight edge boxes and the word arrow's eight boxes. *)

val red : Color_count.range
(** The rectangle's red: red 180..255, green and blue 0..125. Headroom on the
    mGBA frames: red 239 and 255 (59 over the floor), green and blue 82 and 0
    (43 under the ceiling). *)

val min_red_share : float
(** 0.15 of an edge box red: the rectangle's left edge, one pixel of the box's
    four columns (x 16-19, wide for a capture a pixel off), fills 0.25 of it on
    mGBA, a box off the rectangle 0. *)

val group_cell : Effects.measurements -> cell option
(** The grid cell in the red rectangle: the only edge box at least
    {!min_red_share} red; [None] with none or several (no grid). *)

val word_cell : Effects.measurements -> cell option
(** The word list cell with the arrow ({!Cursor_column.row} over the eight
    boxes, row by row); [None] with no clear arrow (no list). *)
