(** Cyclomatic complexity per function, advisory only: 1 + decision points
    ([if], [while], [for], [&&], [||], each [when] guard, and each match or
    handler arm after the first). A match whose arms have no guards and no
    decisions is a table lookup and adds nothing. *)

val check : Config.t -> Parsed_source.t -> Finding.t list
(** An advisory finding per function above [complexity_advisory]. *)
