(** Errors are values: code under a [no_exceptions] root returns a [Result]
    instead of raising. Flags an [exception] declaration (top level or
    [let exception]), an [exn] extension, any use of [raise], [raise_notrace],
    [failwith] or [invalid_arg] (called or passed as a value), and a
    [try ... with] or [match ... with exception] that catches one. It reads the
    parse tree, so comments and strings never trigger it. Calls that raise
    inside the standard library ([List.hd], [Option.get]) are not flagged. *)

val check : Parsed_source.t -> Finding.t list
