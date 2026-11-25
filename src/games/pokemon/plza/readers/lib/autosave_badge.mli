(** Reader: the autosave badge's pencil shows at the top right, in any language
    (the screen's autosave reading). Ported from
    PokemonLZA_AutosaveDetector.cpp: on the 1080p frame the icon box x
    1603-1629, y 73-103 is 8-40% white and 25% dim cyan at least
    ({!Pixel_shares.white}, {!Pixel_shares.dim_cyan}); the strips left of it (x
    1570-1597), above (y 56-69) and below (y 108-121) are under 5% white and
    under 5% cyan. Text shorter than Chinese moves the right-aligned icon right,
    so it is looked for up to 240 pixels right, four at a time. A cutscene flash
    is bright left of it too, and glowing scenery glows on above and below. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The probes {!shown} needs, for a game picture at [picture] in the frame. *)

val shown : Effects.measurements -> bool
(** The icon shows at some place. [false] when a probe is missing. *)
