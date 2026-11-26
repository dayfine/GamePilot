(** Finding one piece of text inside another, as a log line or a page is read
    back. *)

val contains : string -> string -> bool
(** [contains text part]: [part] occurs somewhere in [text]; the empty [part]
    occurs in every [text]. *)
