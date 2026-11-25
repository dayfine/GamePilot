(** The "did you mean" of an unknown name: the known names closest to it in edit
    distance, for an error message. *)

val distance : string -> string -> int
(** The Levenshtein distance: the fewest single-character insertions, deletions
    and substitutions that turn one string into the other. *)

val closest : string -> string list -> string list
(** The known names nearest to the name (all those at the least distance, in
    order), when that distance is at most a third of its length (and at least
    2); [[]] when none is that near. *)

val unknown : what:string -> string -> string list -> string
(** ["no place \"dept_store_4f_clerkk\"; did you mean dept_store_4f_clerk?"] for
    [what = "place"], or without the question when no name is near. *)
