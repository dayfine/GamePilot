(** Finding one piece of text inside another, as a log line or a page is read
    back. *)

val find : ?from:int -> string -> string -> int option
(** [find ~from text part]: where [part] first occurs in [text] at or after
    [from] (default 0), if it does; the empty [part] occurs at [from] when
    [from] is within [text] or at its end. *)

val contains : string -> string -> bool
(** [contains text part]: [part] occurs somewhere in [text]; the empty [part]
    occurs in every [text]. *)
