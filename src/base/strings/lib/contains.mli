(** Whether one piece of text occurs inside another, as a log line or a page is
    read back. *)

val substring : string -> string -> bool
(** [substring text part]: [part] occurs somewhere in [text]; the empty [part]
    occurs in every [text]. *)
