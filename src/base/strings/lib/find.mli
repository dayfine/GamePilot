(** Where one piece of text first occurs inside another, as a log line or a page
    is read back and cut at what it holds. *)

val substring : ?from:int -> string -> string -> int option
(** [substring ~from text part]: where [part] first occurs in [text] at or after
    [from] (default 0), if it does; the empty [part] occurs at [from] when
    [from] is within [text] or at its end. *)
