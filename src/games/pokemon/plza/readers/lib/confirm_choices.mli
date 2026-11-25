(** Reader: the new game's "Confirm Choices" screen, and which of its three rows
    is highlighted (0 "Change hair color", 1 "Change look", 2 "Ready!"). Ported
    from [read_confirm_choices_cursor] in PokemonLZA_IntroScreens.cpp
    ([plza/lean]): on the 1080p frame, two boxes of the dotted background (x
    620-719, y 742-781; x 770-799, y 580-899) are dark and blue (brightness
    under 90, stddevs summing to 80 at most, red 30 at most and blue over red by
    40), and of the three row strips (100 wide from x 620; y 592 and 676, 40
    high; y 820, 60 high) exactly one is white and flat (every channel 200 up,
    stddevs summing to 30 at most) and the others slate (red 20-55, green 40-80,
    blue 65-115, blue over red by 25, stddevs summing to 30 at most).

    Where it differs: a plain row's slate is wider (red 10-65, green 30-90, blue
    50-125, blue over red by 15): the fork's bounds miss rows of these frames a
    tenth dimmer or with blue 12 down (row 0 of English_1 is green 43, blue 68).

    Not ported: the name and language OCR of the screen ([check_profile]); the
    fork checks both before it confirms. *)

val ready_row : int
(** 2: "Ready!". *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The probes {!read} needs, for a game picture at [picture] in the frame. *)

val read : Effects.measurements -> int option
(** The highlighted row, or [None] on any other screen (or a missing probe). *)
