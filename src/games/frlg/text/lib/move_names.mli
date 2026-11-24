(** FRLG move names as the game shows them (["KARATE CHOP"]), by the plans'
    slugs (["karate-chop"]), from the file
    [src/games/frlg/assets/extract/extract_frlg_move_names.py] writes
    (pret/pokefirered's [move_names.h]). *)

type t = (string * string) list
(** (slug, name), in the game's move order. *)

val of_string : string -> t
(** Parses the file's text: [<slug> <name>] per line, [#] lines left out. *)

val load : string -> t

val name : t -> string -> string option
(** The name of this slug. *)
