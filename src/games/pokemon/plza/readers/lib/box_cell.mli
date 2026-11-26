(** Reader: the Boxes' cursor is on a cell that holds a Pokémon. Ported from
    PokemonLZA_BoxDetection.cpp, its [SomethingInBoxCellDetector]: on a Pokémon,
    the summary panel on the right shows, its white name bar at the top; on an
    empty cell (a Pokémon held over it or not) no panel shows. The bar's left
    end (0.453, 0.100, 0.009, 0.059) and right end (0.947, 0.107, 0.010, 0.052)
    of the frame are both white: mean summing to 500 or more, stddevs to 15 at
    most ({!Box_color.is_white}).

    Where it differs: the fork also matches the right stick's up-down icon
    beside the panel (its [ButtonDetector]); here the two white ends alone. The
    steps read a cell only on the Boxes ({!Boxes_screen}), where the panel is
    the only white there. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The two ends' [core.color_stats@1] probes. *)

val holds_pokemon : Effects.measurements -> bool
(** Both ends are white; [false] when a probe is missing. *)
