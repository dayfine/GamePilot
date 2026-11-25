(** A game font as data: each character's glyph, drawn from pokefirered's font
    graphics by [src/games/frlg/assets/extract/extract_frlg_font_glyphs.py] into
    [games/frlg/assets/font_latin_<font>.glyphs]: the normal font (names,
    messages) and the small one (the bag's counts, the Berry Pouch's numbers).
    One table per font serves every Western language; Japanese would be more
    tables. *)

type pixel =
  | Background
  | Text
  | Shadow  (** the light outline below and right of each stroke *)

type glyph = {
  width : int;  (** how far the game moves right after drawing it *)
  rows : pixel array array;
      (** the font's height in rows (14 normal, 13 small) of [width] pixels *)
}

type t

val of_string : string -> t
(** Parses the glyph file's text (format in the extractor's doc comment). Raises
    [Failure] on a malformed line or a glyph whose height differs from the
    others'. *)

val load : string -> t
(** [of_string] of the file at this path. *)

val find : t -> Uchar.t -> glyph option
(** The glyph the game draws for this character, if the font has one. *)
