(** Advisory check for test assertions comparing formatted text against string
    literals (R28). *)

val check : Parsed_source.t -> Finding.t list
(** Reports an advisory finding for each equality comparison ([=], [<>] or
    [String.equal]) in a test file that compares [Printf.sprintf], [to_string],
    [*_to_string] or [*_text] output against a string literal. *)
