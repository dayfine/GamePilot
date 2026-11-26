(** The minimaps the fork records at checkpoint starts, by name ([03.03-start]):
    its Programs/AutoStory/ReferenceData/plza-minimap-*.json (recorded on
    console B by PokemonLZA_AutoStory.cpp's Record Start Minimaps, matched by
    Detectors/PokemonLZA_AutoStoryMinimapMatch.cpp), each a 16 x 16 grid of cell
    colours over the minimap's box, row by row, as 16 ["rrggbb"] strings of 16
    cells. Read by {!Minimap}. *)

val all : (string * string list) list
(** Each reference's name and its 16 rows of cells. *)
