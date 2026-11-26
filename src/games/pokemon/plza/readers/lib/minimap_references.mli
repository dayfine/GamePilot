(** The minimaps the fork records at checkpoint starts, named here for the place
    each shows: [after-taunie-battle] (the courtyard past the plaza arch, where
    03.03-battle-taunie ends), [station-front] (where 03.07-pokemon-center
    starts), [pokemon-center-door] (outside the Center, where it ends) and
    [wild-zone-1-gate] (where 03.09-first-catches starts). The grids are the
    fork's Programs/AutoStory/ReferenceData/plza-minimap-*.json (plza/lean: its
    03.03, 03.04, 03.06 and 03.07 starts, in that order), recorded on console B
    by PokemonLZA_AutoStory.cpp's Record Start Minimaps, matched by
    Detectors/PokemonLZA_AutoStoryMinimapMatch.cpp: each a 16 x 16 grid of cell
    colours over the minimap's box, row by row, as 16 ["rrggbb"] strings of 16
    cells. Read by {!Minimap}. *)

val all : (string * string list) list
(** Each reference's name and its 16 rows of cells. *)
