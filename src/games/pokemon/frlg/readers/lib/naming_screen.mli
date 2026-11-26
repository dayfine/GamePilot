(** Reader: the naming screen's keyboard (a box's name, the player's, a
    Pokémon's nickname): which page shows and which key the cursor is on. New,
    not in the fork, which has no FRLG naming screen. Laid out from pokefirered
    src/naming_screen.c and measured on mGBA frames of BOX NAME? (Route 4
    Pokémon Center's PC, 2026-11-25), in GBA pixels:

    - each page fills the keyboard with its own colour: blue (123, 173, 198) for
      the capitals, orange (214, 156, 115) for the small letters, green (148,
      189, 107) for the others (digits and symbols). {!page} reads a patch right
      of the keys (x 168-175, y 96-135) that only the background covers, and
      only when the white box of the text entry shows right of the entry (x
      168-199, y 50-59): a box screen's Forest wallpaper is the others page's
      green.
    - the cursor is a rounded rectangle around the key, centred at x
      [column_x + 38] and y [88 + 16 row] ([SetCursorPos]); its colour cycles
      between red and white about twice a second ([SetCursorFlashing]). {!key}
      finds its left edge (x [centre - 6] to [centre - 4], y [centre - 6] to
      [centre - 2]) at the cycle's red end, about half the frames: a reader
      awaits a frame that shows it. On the button column (the page button, BACK,
      OK) the game hides the cursor and flashes the button: {!key} reads [None]
      there. *)

(** A page of keys; SELECT turns to the next. *)
type page =
  | Upper  (** ABCDEF ... *)
  | Lower  (** abcdef ... *)
  | Others  (** 01234, 56789, !?♂♀/-, …“”‘' *)

type key = { row : int; col : int }
(** A key: row 0..3 (top first), column from 0 on the left. *)

val rows : int
(** 4. *)

val columns : page -> int
(** Key columns: 8 on the letter pages, 6 on the others page
    ([sPageColumnCounts]); the button column is the next one. *)

val column_x : page -> int -> int
(** A column's x offset in the keyboard ([sPageColumnXPos]): letters 0, 12, 24,
    56, 68, 80, 92, 123; others 0, 22, 44, 66, 88, 110. *)

val probes : Wire.probe_spec list
(** The page patch's three colour counts and one edge box per key of both
    layouts. *)

val page_share : float
(** 0.8: the share of the patch in a page's colour for {!page} to read it; the
    mGBA frames fill it whole, the other two ranges none of it. *)

val upper_blue : Color_count.range
(** Red 90..155, green 140..205, blue 165..230: the capitals' blue (123, 173,
    198), 32 or more each way. *)

val lower_orange : Color_count.range
(** Red 180..245, green 125..190, blue 80..150: the small letters' orange (214,
    156, 115), 31 or more each way. *)

val others_green : Color_count.range
(** Red 115..179, green 155..220, blue 75..140: the others page's green (148,
    189, 107), 31 or more each way. *)

val entry_white : Color_count.range
(** Every channel 200..255: the entry box's white (255, 255, 255). *)

val min_entry_white : float
(** 0.9 of the entry patch white: all of it on the naming screen, 0.6 where a
    box screen's menu covers it (0.7 at brightness x1.1), none on the box grid.
*)

val page : Effects.measurements -> page option
(** The page whose colour fills at least {!page_share} of the patch, the entry
    patch at least {!min_entry_white} white; [None] otherwise (another screen, a
    page sliding in). *)

val cursor_red : Color_count.range
(** Red 225..255, green and blue 0..150: the cursor at the red end of its cycle,
    (252, 111, 123) on the capitals, (255, 102, 82) on the small letters and
    (255, 119, 78) on the others page; it leaves out the cycle's pinks and
    whites, the keys' white glyphs, and every page's background (the small
    letters' orange (214, 156, 115) by its green). *)

val min_cursor_share : float
(** 0.3: the cursor's edge fills 11 of the box's 15 pixels (0.73) on mGBA, a box
    off it none. *)

val key : page -> Effects.measurements -> key option
(** The key whose edge box is at least {!min_cursor_share} cursor red, among the
    page's keys; [None] with none (the white half, the button column) or
    several. *)
