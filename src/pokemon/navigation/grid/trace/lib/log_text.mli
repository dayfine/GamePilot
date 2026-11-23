(** Finding the parts of a log line when reading it back. Positions are byte
    offsets into the text. *)

val is_at : string -> int -> string -> bool
(** [is_at text i part]: [part] occurs in [text] at [i]. *)

val find : ?from:int -> string -> string -> int option
(** [find ~from text part]: where [part] first occurs in [text] at or after
    [from] (default 0). *)

val rfind : string -> string -> int option
(** [rfind text part]: where [part] last occurs in [text]. *)

val slice : string -> int -> int -> string
(** [slice text first past]: the bytes from [first] up to, not including,
    [past]. *)

val int : string -> int option
(** A whole decimal integer, an optional ["-"] then digits and nothing else:
    ["-1"] and ["30"], but not [""], ["+1"], [" 1"] or ["0x1"]. *)
