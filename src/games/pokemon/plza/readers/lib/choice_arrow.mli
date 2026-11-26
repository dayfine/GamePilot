(** Reader: the arrow pointing at a choice box's highlighted row shows. Ported
    from PokemonLZA_SelectionArrowDetector.cpp as 01.02's screen sets it up
    (PokemonLZA_AutoStoryScreenEvents.cpp, PokemonLZA_DialogChoiceBox.cpp): in
    the box from x 960 (room for rows of about 54 characters) to 0.949837 of the
    width, 0.481553 down, 0.312621 high, a blob of 700 pixels at least in one of
    six yellow ranges matching the right-pointing arrow's template
    ({!Blob_template}) with a score under 80. *)

val probes : picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** The probe {!shown} needs, for a game picture at [picture] in the frame. *)

val shown : Effects.measurements -> bool
(** The arrow shows. [false] when the probe is missing. *)

val backup_save_probes :
  picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** The same arrow in the box (0.2, 0.5, 0.6, 0.3): the backup save's arrow
    PLZA's title shows, as the fork's entry from the title into the game
    (PokemonLZA_GameEntry.cpp) watches for it. No frame of that screen yet:
    untested on one. *)

val backup_save_shown : Effects.measurements -> bool
(** The backup save's arrow shows. [false] when the probe is missing. *)
