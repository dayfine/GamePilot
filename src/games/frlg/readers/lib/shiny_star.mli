(** Reader: the shiny star on the summary screen's first page (POKéMON INFO),
    left of the Pokémon's picture. Port of the fork's
    [PokemonFRLG/Inference/PokemonFRLG_ShinySymbolDetector.cpp]: the same box
    (fractions of the game picture), the same color range, and its test: the
    pixels in range average more than 20 redder than blue. A box with no pixel
    in range reads not shiny, as the C++'s zero average does.

    Measured on mGBA frames of the summary (rng-route10-2026-11-25/: a shiny
    Ekans, 23 star pixels of 100 averaging (255, 214, 82); Oddish and Rattata,
    none in range) and the Switch frames of the menu tests (9 with the star,
    pages 1 and 2: the fork's Magikarp and StatsReader images, our own
    Squirtle). Headroom: the star's red stands at least 125 above its blue
    (Switch), 155 on mGBA with its colors shifted, against {!min_red_over_blue};
    a frame without the star has no pixel in range. Every mGBA frame reads the
    same with its brightness times 0.9 or 1.1, any one channel 12 up or down, or
    every channel pulled 10% toward mid-grey. *)

val probes : Wire.probe_spec list

val star : Color_count.range
(** The star's yellow: (193, 152, 0) to (255, 255, 162). *)

val min_red_over_blue : float
(** 20: the C++'s [stats.average.b + 20 < stats.average.r]. *)

val shiny : Effects.measurements -> bool
(** On the summary's first page: the star shows. Read on another screen it means
    nothing. *)
