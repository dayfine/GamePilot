(** Reader: the Pokémon summary screen and its page. Ported from the fork's
    Menus/PokemonFRLG_SummaryDetector (SummaryDetector, SummaryPage2Detector,
    SummaryPage3Detector): the three page marks at the top, the current one
    white (gold while a move's detail shows), the ones before it tan and the
    ones after it blue. The boxes are the fork's, relative to the game picture;
    any language. *)

val probes : Wire.probe_spec list

val page : Effects.measurements -> int option
(** 1 (info), 2 (skills) or 3 (moves, and a move's detail); [None] when the
    marks do not show one of these. *)
