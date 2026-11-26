(** Reader: the new game's screens before "Confirm Choices": the language list,
    the look picker and the name keyboard. Ported from
    PokemonLZA_AutoStoryIntroScreens.cpp and the highlighted-row test of
    PokemonLZA_AutoStoryHighlightedRow.cpp (branch [lab/dev-plza-slice1]), their
    boxes and thresholds, on the 1080p frame:

    - the language list: the dark blue gap between its two columns (x 940-980, y
      357-840) under brightness 70, and of its ten entries (numbered down the
      left column, then the right; strips 65 x 54 at x 385 and 1030, from y 357,
      108 apart) exactly one white and flat (every channel 200 up, stddevs
      summing to 30 at most) and the others slate (red 35-90, green 45-110, blue
      65-140, blue over red by 15, stddevs summing to 20 at most);
    - the look picker: its eight 240 x 240 tiles (left edges x 373, 685, 997,
      1309; tops y 324 and 609), each with a face in its middle (60 x 60 from 90
      right and 100 down: brightness 80 up, stddevs summing to 60 up) and four
      12 x 12 corner patches 10 in from its edges, each white (every channel 200
      up, stddevs summing to 40 at most) or dark blue (brightness under 90, red
      50 at most, blue over red by 20, stddevs summing to 50 at most). The
      highlighted look has four white corners and the others none; as the picker
      opens none is highlighted;
    - the name keyboard, any layout: the question area (x 1056-1824, y 54-184)
      dark and flat (brightness 40 at most, stddevs summing to 15 at most), and
      either the light theme's key row (x 58-1594, y 929-950) at brightness 185
      up or the dark theme's bar (x 192-864, y 1010-1042) flat grey (brightness
      65-90, stddevs summing under 10).

    Not ported: the HOME tile's title, the keyboard's "0/N" counter and Confirm
    Choices' name and language, which the fork reads by OCR. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The probes the readers need, for a game picture at [picture] in the frame.
*)

val language_entries : int
(** 10. *)

val language_entry : Effects.measurements -> int option
(** On the language list, the highlighted entry (0 to 9); [None] on any other
    screen, or with a probe missing. *)

val look_picker_shown : Effects.measurements -> bool
(** The look picker shows, highlighted or not. *)

val looks : int
(** 8. *)

val highlighted_look : Effects.measurements -> int option
(** On the look picker, the highlighted look (1 to 8: left to right along the
    top row, then the bottom one); [None] while none is, while the card moves,
    and on any other screen. *)

val name_keyboard_shown : Effects.measurements -> bool
(** The Switch's name keyboard (Latin, Hangul or Chinese, light or dark theme).
*)
