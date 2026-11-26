(** Reads the box screen's title (a box's name) back: each candidate drawn where
    the game centres it and matched by its dark outline ({!ink}). New, not in
    the fork. pokefirered pokemon_storage_system_graphics.c ([InitBoxTitle],
    [GetBoxTitleBaseX]) centres the name on x 160, its glyph cells' top at y 22;
    [sBoxTitleColors] draws it white with a shadow RGB(7, 7, 7) on every
    wallpaper, (255, 255, 255) and (57, 57, 57) on mGBA. The font's shadow
    pixels (right of and below each stroke) are what is matched: the white is
    not, because the title bar's pictures have whites of their own behind the
    name (Snow's peaks, Desert's sun, Sky's clouds), where the white text read
    wrong on 6 of the 16 wallpapers and the outline on none.

    Measured on mGBA (2026-11-25) on all 16 wallpapers with the bag-prep code's
    names (docs/design/FRLG-ACE-Execution.md), the hand on the title or on the
    first slot, and on five of them with their colours shifted
    (dev/reader_fixtures/shift_frame.py: brightness x0.9 and x1.1, each channel
    +-12, grey 10): every right name scores 0; the nearest wrong one (G……o
    against Q……o, one letter apart) 0.011. Each candidate's template keeps
    {!margin} blank pixels either side (one more on the left to start on an even
    x, below), so a short name ([A]) does not match inside a longer one that
    holds it (["”‘' A a."]). The hand over a slot of the top row's middle covers
    the name: read with the hand on the title or on the first slot.

    On the Switch (console B, 2026-11-25: Boxes 1-14 named BOX1-BOX14, the hand
    on the title) the GBA picture is scaled 6.5 times, so the template is
    compared on its whole pixels only ([skip_seams]) and starts on an even game
    x and y, where the capture's game pixels start on a whole frame pixel: every
    right name scores at most 0.0007, and at most 0.0032 with the colour shifts
    above. The nearest wrong one there is BOX6 against BOX8 (0.0053): the two
    digits differ by a few outline pixels, so a caller that may see either
    passes both. *)

val margin : int
(** 10. *)

val ink : Wire.color_range
(** Every channel 0..98: the outline's (57, 57, 57) on mGBA and the Switch's
    blurred outline, not the title bars' darkest pictures (99 on Seafloor and
    City). *)

val max_score : float
(** 0.006: about half the nearest wrong name's score on mGBA, much tighter than
    {!Line_reading.max_score}, since one letter changed in a name scores 0.011
    there (BOX6 against BOX8 less, see above). A caller still passes every name
    the box may show as a candidate, so a near name loses to the right one. *)

val pick :
  Glyph_table.t -> string list -> Effects.measurements -> Line_reading.reading
(** The best candidate, each scored on its own line, within {!max_score}. *)

val read : Glyph_table.t -> string list -> (Line_reading.reading, string) result
(** Uploads each candidate's template, picks from the first frame with all their
    probes; [Error] when a candidate cannot be drawn or no such frame comes
    within a second. *)

val probes :
  Glyph_table.t -> string list -> (Wire.probe_spec list, string) result
(** Each candidate's probe, its template uploaded. *)

val template : Glyph_table.t -> string -> (Text_lines.t * string, string) result
(** The candidate's line and PNG template (its outline): for the offline probe
    specs. *)

val probe_of : Text_lines.t -> string -> template:string -> Wire.probe_spec
(** The candidate's probe over its line's glyph rows 0-11 with 2 pixels' slack,
    on the template's whole pixels; [template] is the upload's hash or, offline,
    the PNG's path. *)
