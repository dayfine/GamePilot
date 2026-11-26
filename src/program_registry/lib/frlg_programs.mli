(** Pokémon FireRed/LeafGreen's game metadata and registered program
    descriptors. *)

val game : Descriptor.game
(** The FRLG game descriptor, including its Switch HOME tile and delete-save
    icon. *)

val all : Descriptor.t list
(** Every registered FRLG program, in registry order. *)
