(** Flags ambiguous return types in library interfaces (R19): [result option],
    [bool * bool], and [option option]. *)

val check : path:string -> string -> Finding.t list
(** Walks every [val] declaration in a library [.mli] and flags final return
    types matching [result option], [bool * bool] or [option option]. A file
    that does not parse yields a [parse] finding. *)
