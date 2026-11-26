(** Pokémon HOME's game metadata and registered program descriptors. *)

val game : Descriptor.game
(** The Pokémon HOME game descriptor. *)

val all : Descriptor.t list
(** Every registered Pokémon HOME program, in registry order. *)
