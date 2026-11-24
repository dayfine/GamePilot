(** Every [.ml] in a library directory has an [.mli]. *)

val check : Config.t -> string list -> Finding.t list
(** [check config files] over the scanned file list. *)
