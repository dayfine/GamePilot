(** A UTF-8 string cut into its characters, for text drawn or typed one
    character at a time (a font's glyphs, a keyboard's keys). A byte that does
    not start a valid UTF-8 sequence counts as one character (U+FFFD for
    {!uchars}). *)

val chars : string -> string list
(** Each character as its own UTF-8 string: ["…“"] is [["…"; "“"]]. *)

val uchars : string -> Uchar.t list
(** Each character as a code point. *)
