(** The four ways a player faces or steps on a tile map. Row 0 is the top of a
    map, so [South] increases y. *)

type t = North | East | South | West

val all : t list
(** North, east, south, west. *)

val name : t -> string
(** The lowercase name map files use: ["north"], ["east"], ... *)

val of_name : string -> t option
(** The direction a map file's name stands for, or [None]. *)

val is_across : t -> bool
(** East or west: along a row rather than a column. *)
