(** Nesting depth, measured as indentation of ocamlformat output (two spaces per
    level) plus one structural rule.

    Per function: average depth above [max_function_avg_depth] or any line
    deeper than [max_function_depth]. Per file: average depth above
    [max_file_avg_depth]. Nested else: an [else] that reaches another [if]
    through [let]s or sequences (not a direct [else if]) means the else branch
    is a function of its own. *)

val check : Config.t -> Parsed_source.t -> Finding.t list
