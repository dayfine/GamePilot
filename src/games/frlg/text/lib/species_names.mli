(** FRLG species names as the game shows them (["MR. MIME"]), by the plans'
    slugs (["mr-mime"]), from the file
    [src/games/frlg/assets/extract/extract_frlg_species_names.py] writes
    (pret/pokefirered's [species_names.h]). *)

type t = (string * string) list
(** (slug, name), in the game's species order. *)

val of_string : string -> t
(** Parses the file's text: [<slug> <name>] per line, [#] lines left out. *)

val load : string -> t
