(** A tile of a named map, as the route log writes it: ["Route 202 (23, 25)"].
*)

type t = { map : string; pos : Grid_maps.Tile_pos.t }

val to_string : t -> string
(** ["Route 202 (23, 25)"]. *)

val describe : t list -> string
(** The tiles, comma-separated; ["an unknown tile"] for none. *)

val parse_list : string -> t list
(** {!describe}'s text read back: ["Route 202 (23, 25), Route 202 (30, 26)"].
    [[]] for text that is not a list of tiles, ["an unknown tile"] included. *)
