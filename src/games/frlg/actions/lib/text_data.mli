(** The text reader's data, loaded once from the repo: the font's glyphs, the
    item names and the move names ({!Frlg_text.Data_files}). A file not found
    fails the action as [no_text_data] (repeats). *)

val glyphs : unit -> Frlg_text.Glyph_table.t
val item_names : unit -> Frlg_text.Item_names.t

val move_names : unit -> Frlg_text.Move_names.t
(** English: the language the readers are measured on. *)
