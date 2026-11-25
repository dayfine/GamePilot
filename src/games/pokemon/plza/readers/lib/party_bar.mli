(** Reader: the overworld party bar shows at the bottom left, so the player can
    move (the fork's can-move event). Ported from
    PokemonLZA_PartyBarDetector.cpp, its empty-last-slot check: on the 1080p
    frame the sixth slot's empty frame (x 458-523, y 954-1019, a 2 px line) is
    the scene under a light veil with the inside darkened, so on each of its
    four edges (read along the middle, 8 px clear of the rounded corners) the
    line's mean brightness is at least 10 above a 3 px strip 2 px inside it and
    no lower than one 2 px outside it. The fork measured the line 21-60 lighter
    than inside with the last slot empty, and at most 2 on 686 cutscene frames.

    The bar also shows when its D-pad marker does ({!Party_marker}), as the
    fork's party bar detector takes either.

    The filled slots are counted by {!Party_slots}, from a second frame. *)

val probes : picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** The probes {!shown} needs, for a game picture at [picture] in the frame. *)

type margin = { inside : float; outside : float }
(** One edge: how much brighter its line is than the strip inside and the one
    outside. *)

val margins : Effects.measurements -> margin list option
(** The four edges' margins (top, bottom, left, right); [None] when a probe is
    missing. *)

val last_slot_empty : Effects.measurements -> bool
(** Every edge clears its margins: the last slot's empty frame shows. [false]
    when a probe is missing. *)

val shown : Effects.measurements -> bool
(** The bar shows: its D-pad marker, or its last slot empty. *)
