(** The game's font as data: each character's glyph, drawn from pokefirered's
    font graphics by [tools/extract_frlg_font_glyphs.py] into
    [games/frlg/assets/font_latin_normal.glyphs]. One table serves every Western
    language; Japanese would be a second table. *)

type pixel =
  | Background
  | Text
  | Shadow  (** the light outline below and right of each stroke *)

type glyph = {
  width : int;  (** how far the game moves right after drawing it *)
  rows : pixel array array;  (** {!glyph_height} rows of [width] pixels *)
}

type t

val glyph_height : int
(** Every Latin glyph of the normal font is 14 pixels tall. *)

val of_string : string -> t
(** Parses the glyph file's text (format in the extractor's doc comment). Raises
    [Failure] on a malformed line. *)

val load : string -> t
(** [of_string] of the file at this path. *)

val find : t -> Uchar.t -> glyph option
(** The glyph the game draws for this character, if the font has one. *)
