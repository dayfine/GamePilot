(** Draws a line of text the way the game does: each glyph at the pen, the pen
    moving right by the glyph's width (Latin text has no letter spacing in
    FRLG), on a background of fixed width so that a shorter word does not match
    the start of a longer one. *)

type rgb = { r : int; g : int; b : int }
(** 0..255 per channel *)

type style = { text : rgb; shadow : rgb; background : rgb }
(** The three colors a text window draws with. *)

type image = { width : int; height : int; pixels : Bytes.t }
(** 8-bit RGB, row by row, 3 bytes per pixel. *)

val text_width : Glyph_table.t -> string -> (int, string) result
(** The UTF-8 text's width in game pixels, or [Error] naming a character the
    font lacks. *)

val draw :
  Glyph_table.t ->
  style ->
  width:int ->
  indent:int ->
  top:int ->
  height:int ->
  string ->
  (image, string) result
(** [draw glyphs style ~width ~indent ~top ~height text] draws [text] from
    [indent] pixels right of the image's left edge onto a [width]-pixel
    background and keeps glyph rows [top] .. [top + height - 1]. [Error] when a
    character is missing or the text does not fit. *)
