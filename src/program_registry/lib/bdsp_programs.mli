(** Pokémon Brilliant Diamond / Shining Pearl's game metadata and registered
    program descriptors. *)

val game : Descriptor.game
(** The BDSP game descriptor. *)

val all : Descriptor.t list
(** Every registered BDSP program, in registry order. *)
