(** Boxes measured in the GBA's own pixels (240 by 160), as the fork's newer
    readers state them (Inference/Menus/PokemonFRLG_ItemListReader.cpp,
    Inference/Box/PokemonFRLG_PcScreenReader.cpp), turned into the probe boxes
    of the wire, which are fractions of the game picture. *)

val width : float
val height : float

val box : Wire.box -> Wire.box
(** [box { x; y; w; h }] with all four in game pixels: the same box as fractions
    of the picture. *)
