(** Reader: the tutorial's controls hint (the "?" card above "(L) Move") shows,
    so the player has control (the screen's [controls_hint] reading). Ported
    from PokemonLZA_ControlsHintDetector.cpp: on the 1080p frame the card at x
    947-970, y 872-899 is 80% sky blue at least ({!Pixel_shares.sky_blue}), the
    "?" at x 955-962, y 879-885 70% at most, and the strips left, right, above
    and below it 10% at most. More rows of hints raise the card, so it is looked
    for from 60 pixels above to 20 below, two pixels at a time. A sky behind
    comes closest (card 76%, "?" 100%, around 54%).

    Where it differs: the "?" may be 90% sky blue, not 70%: on a frame a tenth
    brighter its bluish edges count (80% on one hint). *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The probes {!shown} needs, for a game picture at [picture] in the frame. *)

val shown : Effects.measurements -> bool
(** The card shows at some height. [false] when a probe is missing. *)
