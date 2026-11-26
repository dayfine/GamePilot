(** Reader: the box screen of MOVE POKéMON, for the one slot a check looks at.
    Made from mGBA frames of the Route 4 Pokémon Center's PC (2026-11-25), in
    GBA pixels. Parts ported from the fork's
    Inference/Box/PokemonFRLG_BoxCellOccupiedDetector.cpp/.h: the PKMN DATA
    panel's lower part (the fork's box (0.007, 0.556, 0.296, 0.253) of the game)
    is flat grey with the hand on an empty slot and has text (name, gender,
    level, species) on an occupied one; the fork's test is a stddev sum over 10.

    GamePilot's own:
    - the hand over the box's first slot: its shadow, a blue-grey ellipse (82,
      107, 123) at x 93-105, y 49-55, shows under the hand over an empty slot
      (an icon hides it);
    - the box's wallpaper, by the mean colour of a strip along the grid's foot
      (x 100-219, y 140-151): Box 3's default Desert is tan (208, 167, 117 on
      mGBA), Box 1's Forest green (156, 204, 101). The title's name is drawn
      white with a dark outline, which the text templates do not read;
    - the panel's gender mark: the male symbol's blue at x 10-16, y 117-127;
    - the panel's held-item line ({!holds_item}), flat when the Pokémon holds
      nothing. *)

val probes : Wire.probe_spec list
(** The panel's lower part, the held-item line, the first slot's shadow box, the
    wallpaper strip, the gender mark's box and the title menu's arrow: every
    probe the functions below read. *)

val title_menu_row : Effects.measurements -> int option
(** The arrow's row (0 JUMP, 1 WALLPAPER, 2 NAME, 3 CANCEL) on the menu A opens
    on the box title in MOVE POKéMON ({!Cursor_column} over x 143-151 of each
    row, rows 16 apart from y 59); [None] with no menu. GamePilot's own,
    measured on mGBA (2026-11-25): the arrow at x 145-149, the window from x
    140. *)

val hand_quick : Effects.measurements -> bool option
(** The hand over the box's first slot is the quick hand SELECT turns on: at
    least {!min_quick_share} of its box (x 90-105, y 20-37, the hand's bob
    included) in {!quick_yellow}. pokefirered pokemon_storage_system_data.c
    [ToggleCursorMultiMoveMode] swaps the hand sprite's palette
    ([cursorPalNums]); the quick one fills the glove (255, 231, 90) with orange
    (255, 181, 107), (255, 165, 0) edges on mGBA, the normal one white.
    GamePilot's own, for the ACE trigger (the actions' Ace_trigger); read
    only with the hand on the first slot. *)

val quick_yellow : Color_count.range
(** Red 225..255, green 200..250, blue 40..150: the quick glove's yellow.
    Desert's title bar (231, 198, 99) lies outside (green) and right of the box.
*)

val min_quick_share : float
(** 0.12: the quick hand fills 0.20-0.25 of the box on mGBA, the normal hand
    0. *)

val panel_occupied : Effects.measurements -> bool option
(** The fork's test: the panel's stddev sum over {!min_panel_stddev}. *)

val min_panel_stddev : float
(** 10, the fork's. Measured on mGBA: an empty slot's panel 0, the ACE Pokémon's
    200 and more. *)

val holds_item : Effects.measurements -> bool option
(** PKMN DATA's held-item line has text: the channel stddevs' sum over
    {!min_panel_stddev} in x 2-69, y 134-143, where pokefirered
    [PrintDisplayMonInfo] prints the item's name in the small font (window 0 at
    (0, 88), the text at (6, 44)); flat with no item or an empty slot. *)

val hand_on_first_slot : Effects.measurements -> bool option
(** The hand's shadow fills at least {!min_shadow_share} of the first slot's
    shadow box. Only over an empty slot. *)

val shadow : Color_count.range
(** Red 50..115, green 75..140, blue 90..160: the shadow (82, 107, 123) with 25
    or more each way; the wallpapers (Forest, Desert) and the box frame lie
    outside. *)

val min_shadow_share : float
(** 0.25: the shadow fills 28 of the box's 13 x 7 pixels (0.31) on mGBA. *)

val desert_wallpaper : Effects.measurements -> bool option
(** The strip's mean is tan: red over green by at least 15, green over blue by
    at least 20 (mGBA: 41 and 50). Forest (green over red) is not. *)

val male : Effects.measurements -> bool option
(** The male symbol's blue fills at least 0.15 of its box (mGBA: 0.3). *)

val forest_wallpaper : Effects.measurements -> bool option
(** The strip's mean is green: green over red and over blue by at least 20
    (mGBA: 48 and 103). Box 1's default Forest. *)
