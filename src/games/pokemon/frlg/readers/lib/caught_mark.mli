(** Reader: the Poké Ball mark on a wild foe's HP box, which FireRed draws when
    the foe's species is caught in the Pokédex. New: the fork reads no such
    mark. A capture that collects species runs from a foe with the mark and
    catches one without it, with no Pokédex page opened.

    From pret pokefirered [src/battle_interface.c]: the mark is one 8 by 8 tile
    of the HP bar's sprite, copied in for a wild battle's foe whose species has
    its caught flag, and cleared while the foe has a status (a foe put to sleep
    shows none). Trainer battles, the first battle and the Old Man's never show
    it. The ball's outline sits at x 20 to 26, y 31 to 37 of the picture, left
    of the HP bar, with the HP box's cream above and left of it; while the box
    slides in, its HP bar passes there, which the cream tells apart.

    Measured on mGBA frames of Route 10's wild battles (dex-route10/: Spearow,
    caught; Ekans and Voltorb, not) and the Switch captures of the battle tests
    (9 with the mark). Headroom: the mark is 0.26 of the box at the least
    (Switch), 0.37 on mGBA, against {!min_share}; a frame without it, 0.06 at
    the most; the cream's lowest channel 200 (mGBA times 0.9) against
    {!min_cream_channel}, its stddev sum 25 at the most (Switch). Every mGBA
    frame reads the same with its brightness times 0.9 or 1.1, any one channel
    12 up or down, or every channel pulled 10% toward mid-grey (the battle
    tests' shifted fixtures). *)

val probes : Wire.probe_spec list
(** Every probe {!caught} needs. *)

val dark_max : int
(** The mark's outline, (74, 66, 90) on mGBA: each channel at most this. Its
    grey band, (132, 132, 140), is above it. *)

val min_share : float
(** A mark: outline pixels in its box at least this share... *)

val max_share : float
(** ...and at most this: a box that dark is not the cream HP box. *)

val min_cream_channel : float
(** The cream above and left of the mark ((255, 255, 222) on mGBA): each
    channel's mean at least this... *)

val max_cream_stddev_sum : float
(** ...and the channels' stddev summed at most this. *)

val caught : Effects.measurements -> bool
(** The foe's HP box, settled, with the mark. *)

val read : Effects.measurements -> bool option
(** {!caught}, or [None] on a frame without the probes (one measured before they
    were subscribed). *)
