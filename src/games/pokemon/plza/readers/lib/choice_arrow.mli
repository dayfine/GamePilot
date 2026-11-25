(** Reader: the arrow pointing at a choice box's highlighted row shows. Ported
    from PokemonLZA_SelectionArrowDetector.cpp as 01.01's screen sets it up
    (PokemonLZA_AutoStoryScreenEvents.cpp, PokemonLZA_DialogChoiceBox.cpp): in
    the box from x 960 (room for rows of about 54 characters) to 0.949837 of the
    width, 0.481553 down, 0.312621 high, a blob of 700 pixels at least in one of
    six yellow ranges matching the right-pointing arrow's template
    ({!Blob_template}) with a score under 80. *)

val probes : picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** The probe {!shown} needs, for a game picture at [picture] in the frame. *)

val shown : Effects.measurements -> bool
(** The arrow shows. [false] when the probe is missing. *)
