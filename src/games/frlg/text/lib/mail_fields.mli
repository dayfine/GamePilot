(** Reads a word field of the Easy Chat mail editor (the screen giving mail
    opens), for the Mail Glitch's proof that the glitched record is read back
    (docs/mail-glitch-use.md, proof A): field 1 shows the word mg-05 wrote
    (ABRA), an empty field (seven underscores, in green), or ["???"] (a word the
    game does not know, as past the mail table). Not in the fork, which does not
    read the editor.

    Each candidate is matched on its own width plus the 17-pixel gap the game
    leaves after a word, so the next field (which starts right after that gap)
    stays out of the template, and a longer word that starts the same way does
    not match. The words use FONT_NORMAL_COPY_1, whose Latin glyphs and widths
    are the normal font's ({!Glyph_table}). *)

val blank : string
(** An empty field: ["_______"] (pokefirered [CHAR_UNDERSCORE], an extra symbol,
    given ['_'] in the glyph table). *)

val unknown_word : string
(** ["???"]. *)

val gap : int
(** The blank pixels after a word: 17. *)

val line : Glyph_table.t -> string -> Text_lines.t
(** Field 1's line for this candidate: its width plus {!gap}. Raises
    [Invalid_argument] for a character the font lacks. *)

val pick :
  Glyph_table.t -> string list -> Effects.measurements -> Line_reading.reading
(** The best of the candidates, each scored on its own {!line}. *)

val read : Glyph_table.t -> string list -> Line_reading.reading
(** Uploads each candidate's template, subscribes them, picks from the first
    frame with them all, and unsubscribes. Raises [Failure] if no such frame
    comes within a second. *)

val await_read :
  Glyph_table.t -> string list -> timeout_ms:int -> Line_reading.reading
(** As {!read}, but from the first frame on which a candidate reads, for an
    editor still opening; after [timeout_ms], the last frame's reading (or
    [No_match] when no frame had the probes). *)

(** {1 Any field} *)

val first_left : int
(** A row's first field starts at x 41 ({!Text_lines.mail_field_one}). *)

val cursor_width : int
(** The editor's field cursor, the arrow drawn just before a field: it fills the
    last 8 pixels of the gap before that field (x 117-122 before a field at 124,
    on a Switch capture of the ? Mail). *)

val next_left : Glyph_table.t -> left:int -> string -> (int, string) result
(** Where the field after one showing this text starts: after its width and the
    {!gap}. [Error] names a character the font lacks. *)

val read_field :
  Glyph_table.t ->
  row:int ->
  left:int ->
  string list ->
  (Line_reading.reading, string) result
(** The field on [row] (0..4) starting at [left] read as the best of the
    candidates, each scored on its own width plus the {!gap} less the
    {!cursor_width} ({!Text_lines.mail_field}): the cursor on the next field
    stays out of the template, and 9 blank pixels still tell a longer word that
    starts the same way, from the first frame with all their probes; [Error] for
    a character the font lacks or no such frame within a second. *)
