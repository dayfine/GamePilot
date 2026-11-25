(** A tile of a map, in that map's own coordinates. *)

type t = { x : int; y : int }

val next : t -> Direction.t -> t
(** The tile one step away in that direction (it may lie off the map). *)

val to_string : t -> string
(** ["(x, y)"]. *)

val compare : t -> t -> int
(** x, then y: an order for sets and maps of tiles, not a walking order. *)

val equal : t -> t -> bool
