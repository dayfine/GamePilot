(** Reader: an A prompt in the middle of the screen (["(A) Talk"],
    ["(A) Climb Up"]): the fork's [INTERACT_PROMPT], a [ButtonDetector] for the
    A button (PokemonLZA_ButtonDetector.cpp) over the box of
    PokemonLZA_AutoStoryScreenEvents.cpp (0.3, 0.2, 0.4, 0.65). As the fork
    matches it: the bright pixels in each of eight ranges (0x808080 to white up
    to 0xf0f0f0 to white), blobs of at least 250 pixels and 25 x 25 (its 1000
    and 50 x 50 at 4K, scaled to 1080p), whose aspect and fill are within 0.8 to
    1.25 of the template's and whose score is under 70. Whether a text box hides
    it is {!Story_screen}'s. *)

val probes : picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** The probe, for a game picture at [picture] in the frame. *)

val shown : Effects.measurements -> bool
(** An A button shows in the box; [false] when the probe is missing. *)
