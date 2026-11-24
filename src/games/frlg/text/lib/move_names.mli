(** FRLG move names as the game shows them in one language (["KARATE CHOP"]), by
    the plans' slugs (["karate-chop"]), from a file
    [src/games/frlg/assets/extract/extract_frlg_move_names.py] writes (Packages'
    [BattleMovesOCR.json], the first name of each slug). *)

type t = (string * string) list
(** (slug, name), in the file's order. *)

val of_string : string -> t
(** Parses the file's text: [<slug> <name>] per line, [#] lines left out. *)

val load : string -> t
(** [load (Data_files.move_names ~language)]. *)

val name : t -> string -> string option
(** The name of this slug. *)
