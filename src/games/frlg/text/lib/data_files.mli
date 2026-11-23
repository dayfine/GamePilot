(** Where the text reader's data lives in the repo: the glyph table and item
    names and the TM and HM moves under [src/games/frlg/assets/] (made from
    pokefirered), and the move names read in place from the Packages submodule.
    Paths are relative to the repo root; {!locate} finds them from the working
    directory. *)

val glyph_table : string
(** The FRLG normal font's Latin glyphs. *)

val small_glyph_table : string
(** The FRLG small font's Latin glyphs. *)

val item_names_eng : string
(** English item names by pocket. *)

val species_names_eng : string
(** English species names by slug. *)

val tm_hm_moves_eng : string
(** The moves the English TMs and HMs teach. *)

val move_names : string
(** Packages' [PokemonFRLG/BattleMovesOCR.json]: move names per language. *)

val locate : string -> string option
(** The first [dir/path] that exists, trying the working directory and then each
    parent. *)
