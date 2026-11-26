(** Where the text reader's data lives in the repo: the glyph tables, the item
    and species names and the TM and HM moves under
    [src/games/pokemon/frlg/assets/] (made from pokefirered), and the move names
    there (made from Packages). Paths are relative to the repo root; {!locate}
    finds them from the working directory. *)

val glyph_table : string
(** The FRLG normal font's Latin glyphs. *)

val small_glyph_table : string
(** The FRLG small font's Latin glyphs. *)

val item_names_eng : string
(** English item names by pocket. *)

val species_names_eng : string
(** English species names by slug. *)

val easy_chat_words_eng : string
(** The English Easy Chat groups and words, in the editor's order. *)

val tm_hm_moves_eng : string
(** The moves the English TMs and HMs teach. *)

val move_names : language:string -> string
(** Move names by slug in this language (["eng"], ["deu"], ["fra"], ["ita"],
    ["spa"], ["jpn"]), made from Packages' [BattleMovesOCR.json]. *)

val locate : string -> string option
(** The first [dir/path] that exists, trying the working directory and then each
    parent. *)
