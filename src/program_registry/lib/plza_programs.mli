(** Pokémon Legends: Z-A's game metadata and registered program descriptors. *)

val game : Descriptor.game
(** The PLZA game descriptor, including its delete-save icon. *)

val all : Descriptor.t list
(** Every registered PLZA program, in registry order. *)
