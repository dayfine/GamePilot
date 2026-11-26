(** Reader: the Pokédex opened from the Start menu, its table of contents and
    its numerical list. New: the fork reads neither (its Pokédex detector reads
    the page a catch registers). The list's names and numbers are text, read
    with the game's font by the action that reads a species' entry; this module
    tells the screens apart, finds the list's arrow and reads a row's caught
    mark.

    Laid out as pret pokefirered's src/pokedex_screen.c draws them: both screens
    have a tan bar along the top and the bottom. The table of contents opens
    with its arrow on NUMERICAL MODE (the Pokédex's state is made new each time
    it opens) and shows the seen and owned counts and a green circle on the
    right. The numerical list (window at tile (2, 2), 9 rows 14 pixels apart
    from y 18) shows every species from No001 to the highest seen, its name or
    ["-----"]; its arrow at x 21, the caught mark (a Poké Ball, 12 by 12) at x
    56 of a caught species' row, and nothing right of the type icons.

    Measured on mGBA frames of the Mail Glitch save's Pokédex (pokedex-list/,
    2026-11-25) and their shifted versions. Headroom (worst reading on the
    thing; worst off it): the bars' hue 0.022 from tan against
    {!max_tan_distance} 0.04, stddev 0; the list's right panel, lowest channel
    220 (times 0.9) against {!min_panel_channel} 190, stddev sum 15 against
    {!max_panel_stddev_sum} 40, where the table of contents shows 106 at the
    least; the contents' arrow 0.28 of its box against {!min_arrow_share} 0.12,
    0 on the list; the list's arrow 0.26 against the column's 0.10; the caught
    mark 0.35 of its box against {!min_caught_share} 0.15, 0 on a row without
    it. Every frame reads the same with its brightness times 0.9 or 1.1, any one
    channel 12 up or down, or every channel pulled 10% toward mid-grey (the dex
    tests' shifted fixtures). No Switch frame yet. *)

val probes : Wire.probe_spec list
(** Every probe the readers below need. *)

val contents_shown : Effects.measurements -> bool
(** The table of contents with its arrow on NUMERICAL MODE. *)

val list_shown : Effects.measurements -> bool
(** The numerical list. *)

val cursor_row : Effects.measurements -> int option
(** The list's arrow: the shown row (0..8) it is on; [None] off the list. *)

val caught : Effects.measurements -> int -> bool
(** The list shows, and its shown row [row] has the caught mark. *)

(** {1 Thresholds} *)

val tan : Wire.rgb
(** The bars' hue, as channel shares: (198, 181, 140) on mGBA. *)

val max_tan_distance : float
(** A bar: its hue within this of {!tan}'s ({!Solid_color.is_solid})... *)

val max_bar_stddev_sum : float
(** ...and flat: the channels' stddev summed at most this. *)

val min_panel_channel : float
(** The list's right panel (x 206 to 235, y 40 to 129), off white: each
    channel's mean at least this... *)

val max_panel_stddev_sum : float
(** ...and flat: the table of contents' counts and circle are not. *)

val min_arrow_share : float
(** The contents' arrow, dark (each channel at most {!Cursor_column.dark_max}):
    at least this share of its box. *)

val red_low : int
(** The caught mark's red: red at least this... *)

val red_high : int
(** ...green and blue at most this ((236, 48, 0), (220, 48, 16) and (196, 48,
    40) on mGBA; its pale highlight and white not counted). *)

val min_caught_share : float
(** The mark: that red at least this share of its box. *)
