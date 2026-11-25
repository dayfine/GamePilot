(** Libraries a directory never links, directly or through another library: the
    config's [never_links] rules ({!Config}). A stanza in a directory a rule
    matches is a finding when it links one of the rule's libraries, or a library
    of the scanned tree that links one, however deep. A library is known by its
    [name] and its [public_name]. *)

val check : Config.t -> (string * string) list -> Finding.t list
(** [check config dune_files] where each element is [(path, contents)]. *)
