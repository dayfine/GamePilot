(** Nesting depth, measured as indentation of ocamlformat output (two spaces per
    level) plus one structural rule.

    Per function: average depth above [max_function_avg_depth] or any line
    deeper than [max_function_depth], counted from the function's [let] (a
    function in a module or functor body is measured as one at the top). Per
    file: average depth above [max_file_avg_depth], each line counted from the
    module or functor body it is in. Nested else: an [else] that reaches another
    [if] through [let]s or sequences (not a direct [else if]) means the else
    branch is a function of its own. *)

val check : Config.t -> Parsed_source.t -> Finding.t list
