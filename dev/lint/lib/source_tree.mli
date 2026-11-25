(** Finding and reading the files under the configured roots. *)

val files : Config.t -> (string list, string) result
(** Every regular file under the roots, sorted, skipping [_build], dot
    directories and [skip_dir] names. A missing root is an error, so a typo
    never turns into a silent pass. *)

val in_test_dir : Config.t -> string -> bool
(** The path has a [test_dir] segment. *)

val in_library_dir : Config.t -> string -> bool
(** The file's own directory is named [library_dir]. *)

val under_no_exceptions_root : Config.t -> string -> bool
(** The path is inside a [no_exceptions] tree. *)

val under_interface_docs_root : Config.t -> string -> bool
(** The path is inside an [interface_docs] tree. *)

val read : string -> string
(** The whole contents of a file. *)
