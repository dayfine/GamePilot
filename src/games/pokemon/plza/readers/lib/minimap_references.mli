(** The minimaps the fork records at checkpoint starts, by name ([03.03-start]):
    its ReferenceData/plza-minimap-*.json ([plza/lean], recorded on console B by
    AutoStory's Record Start Minimaps), each a 16 x 16 grid of cell colours over
    the minimap's box, row by row, as 16 ["rrggbb"] strings of 16 cells. Read by
    {!Minimap}. *)

val all : (string * string list) list
