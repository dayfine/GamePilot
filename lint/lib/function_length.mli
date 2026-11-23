(** Functions longer than [max_function_lines] (counted from the [let] line to
    the last line of the body). *)

val check : Config.t -> Parsed_source.t -> Finding.t list
