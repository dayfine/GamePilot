(** Layer boundaries from dune [libraries] fields. Each dune directory is placed
    in the first layer whose pattern matches it (see {!Config}). A stanza in a
    layer may link a library defined in the scanned tree only when the [allow]
    table permits the library's layer and every variable both placements bind
    has the same value, and every [family] of the library's layer lists the
    stanza's value of the family's variable. Stanzas outside every layer are not
    checked; linking a library outside every layer from inside one is a finding.
    External libraries are ignored. *)

val check : Config.t -> (string * string) list -> Finding.t list
(** [check config dune_files] where each element is [(path, contents)]. *)

val dir_matches : string list -> string -> bool
(** Whether the directory matches the pattern's segments ({!Config}). *)
