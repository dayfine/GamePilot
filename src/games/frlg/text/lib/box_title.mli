(** Reads the box screen's title (a box's name) back: each candidate drawn where
    the game centres it and matched in {!ink}, the title's white. New, not in
    the fork. pokefirered pokemon_storage_system_graphics.c ([InitBoxTitle],
    [GetBoxTitleBaseX]) centres the name on x 160, its glyph cells' top at y 22,
    white (255, 255, 255) with a dark shadow; measured on mGBA (BOX1 from x 148,
    Az!…'.,9 from x 139, 2026-11-25). The wallpaper's title bar behind it has
    near-whites of its own (Forest: (247, 255, 231), (255, 255, 214)), so the
    ink takes only white within 5 of 255: measured on mGBA's Forest; another
    wallpaper, or a Switch capture's colours, need a check. *)

val ink : Wire.color_range
(** Every channel 250..255. *)

val pick :
  Glyph_table.t -> string list -> Effects.measurements -> Line_reading.reading
(** The best candidate, each scored on its own line, within
    {!Line_reading.max_score}. *)

val read : Glyph_table.t -> string list -> (Line_reading.reading, string) result
(** Uploads each candidate's template, picks from the first frame with all their
    probes; [Error] when a candidate cannot be drawn or no such frame comes
    within a second. *)

val probes :
  Glyph_table.t -> string list -> (Wire.probe_spec list, string) result
(** Each candidate's probe, its template uploaded. *)

val template : Glyph_table.t -> string -> (Text_lines.t * string, string) result
(** The candidate's line and PNG template: for the offline probe specs. *)
