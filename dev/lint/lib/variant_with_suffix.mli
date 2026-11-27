(** Flags variant constructors whose name contains [_with_] (R17). *)

val check_implementation : Parsed_source.t -> Finding.t list
(** Reports every variant constructor matching [*_with_*] (case-insensitive) in
    a library [.ml] file. *)

val check_interface : path:string -> string -> Finding.t list
(** Reports every variant constructor matching [*_with_*] (case-insensitive) in
    a library [.mli] file. A file that does not parse yields a [parse] finding.
*)
