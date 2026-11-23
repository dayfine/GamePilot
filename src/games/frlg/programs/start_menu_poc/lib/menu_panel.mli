(** Reader: is FireRed's Start menu open? The start menu PoC's own reader, kept
    as it was recorded: its wire logs subscribe this probe, so a replay needs it
    unchanged ([Frlg_readers.Start_menu] is the fork's detector).

    The menu is a white panel on the right of the 240x160 screen (about x
    0.70-0.99, y 0.02-0.62) with black text. {!probe} watches the blank strip
    right of the text: near-white and flat when the menu is open, overworld
    colors (roofs, grass) when it is closed. *)

val probe_id : string

val probe : Wire.probe_spec
(** [core.color_stats@1] over x 0.94 w 0.04, y 0.05 h 0.5 of the game picture,
    every frame. *)

(** {1 Thresholds} *)

val min_white : float
(** Every channel's mean must be at least this (0..255). *)

val max_stddev : float
(** Every channel's stddev must be at most this. *)

(** {1 Reader} *)

val start_menu_open : Effects.measurements -> bool
(** False when the probe is missing from the frame. *)
