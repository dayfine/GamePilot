(** Reader: a modal tutorial card shows; only A turns its pages (the screen's
    tutorial card reading). Ported from PokemonLZA_TutorialCardDetector.cpp: the
    card's panel (0.32, 0.62, 0.36, 0.20 of the frame) averages 225 a channel at
    least, and both edges beside it (0.03 and 0.82 across, 0.30 down, 0.15 by
    0.40) average 100 a channel at most with a stddev of 12 a channel at most.
    Measured in the fork on 5 cards and 9 other screens: cards' panels 241-246
    (their text spreads them to 40-48), edges 61-76 with a spread under 7; other
    panels 185 at most, or edges brighter or busy.

    Where it differs: the panel needs 200 a channel, not 225, which a card a
    tenth dimmer (216) misses. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The probes {!shown} needs, for a game picture at [picture] in the frame. *)

val shown : Effects.measurements -> bool
(** A card shows. [false] when a probe is missing. *)
