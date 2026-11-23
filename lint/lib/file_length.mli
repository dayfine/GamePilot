(** Long files. An [.ml] file counts raw lines against [max_file_lines]. An
    [.mli] counts signature lines (lines left after removing comments and blank
    lines) against [max_interface_lines], so documentation never pushes an
    interface over. *)

val check : Config.t -> path:string -> string -> Finding.t list
(** [check config ~path text]; files that are neither [.ml] nor [.mli] pass. *)
