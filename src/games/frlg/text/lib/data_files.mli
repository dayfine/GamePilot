(** Where the text reader's data lives in the repo: the glyph table and item
    names under [src/games/frlg/assets/] (made from pokefirered), and the move
    names read in place from the Packages submodule. Paths are relative to the
    repo root; {!locate} finds them from the working directory. *)

val glyph_table : string
(** The FRLG normal font's Latin glyphs. *)

val item_names_eng : string
(** English item names by pocket. *)

val move_names : string
(** Packages' [PokemonFRLG/BattleMovesOCR.json]: move names per language. *)

val locate : string -> string option
(** The first [dir/path] that exists, trying the working directory and then each
    parent. *)
