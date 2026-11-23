(** One value per tile of a rectangular map, row by row from the top.

    A grid is a value: {!set} returns a new grid and leaves the old one as it
    was. *)

type 'a t

val init : width:int -> height:int -> (Tile_pos.t -> 'a) -> 'a t
(** A [width] x [height] grid whose cell at each tile is [f tile]. Raises
    [Invalid_argument] for a negative size. *)

val width : 'a t -> int
val height : 'a t -> int

val contains : 'a t -> Tile_pos.t -> bool
(** Whether the tile lies inside the grid. *)

val find : 'a t -> Tile_pos.t -> 'a option
(** The cell at a tile, or [None] off the grid. *)

val get : 'a t -> Tile_pos.t -> 'a
(** The cell at a tile inside the grid. Raises [Invalid_argument] off it. *)

val set : 'a t -> Tile_pos.t -> 'a -> 'a t
(** A copy with one cell replaced. Raises [Invalid_argument] off the grid. *)

val positions : 'a t -> Tile_pos.t list
(** Every tile of the grid, row by row from the top. *)
