(** The level in the summary's top left ("Lv33"), shown on every page. Ported
    from the fork's level reader in Inference/PokemonFRLG_StatsReader.cpp
    ([frlg/lean]), which reads the same box on page 1 with its digit templates
    after turning the white text black; here each digit cell
    ({!Text_lines.summary_level_digit}) is matched against the font's digits in
    {!ink}. Like the fork, a level outside 2..100 does not read. English and the
    other Latin languages but Spanish (the fork's [m_box_level]); not Japanese
    or Spanish, whose boxes differ. *)

val ink : Wire.color_range
(** The level's white: red and blue 200..255, green 212..255. The text is a
    neutral white (222 on the moves page, 255 on the info page on mGBA; 218 to
    255 on Switch captures), the header behind it lilac, whose green is the
    lowest channel ((173, 148, 206) on mGBA, up to (252, 205, 253) on a bright
    Switch capture), or teal on the info page ((91, 232, 252) on Switch), whose
    red is low. {!Line_reading.light_ink} takes in the bright lilac. *)

val max_score : float
(** The highest score a digit may read with: 0.125. Right digits score 0 on mGBA
    and up to 0.099 on Switch captures (CommandLineTests' Moltres, the
    brightest); an empty cell 0.158 or more, the move detail's left pane (no
    level shown) too. *)

val max_digits : int
(** 3 (Lv 100). *)

val min_level : int
(** 2: the fork's lowest level read. *)

val max_level : int
(** 100. *)

val of_digits : int option -> int option
(** A number read from the cells, kept when it is a level ({!min_level} ..
    {!max_level}). *)

val read : Glyph_table.t -> int option
(** The level on the open summary page; [None] when its first cell shows no
    digit or the number is not a level. *)
