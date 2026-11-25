(** Reader: whether the cursor is on Pokémon HOME's tile on the Switch's HOME
    menu, by the title over the row, and which of the four whole tiles in view
    is HOME's, by its art. The lab script ([plza_claim_and_bank.sh] in the
    BDSPLab lab tools) moved the cursor along the tiles and read each title with
    tesseract; here each tile's art (the HOME menu reader's slots,
    {!Switch_home.Home_screen}) is searched for the middle of Pokémon HOME's art
    (240x200 from its tile, cut from console B's capture of 2026-11-24) by a
    [core.template_match@1] probe: 0.0067 at most on its tile, cursor on it or
    not, and 0.16 at least on the other games' tiles. *)

val probes :
  art:Effects.template_hash ->
  title:Effects.template_hash ->
  Wire.probe_spec list
(** The title's probe and the four tiles' probes, on the whole frame, with the
    art's and the title's templates. *)

val on_home_tile : Effects.measurements -> bool
(** The cursor is on Pokémon HOME's tile: the title over the row reads "Pokémon
    HOME": a template of its "HOME" (cut from console B's capture of 2026-11-24,
    142x48 at (414, 218)), searched 12 pixels round its place, as its cyan ink
    (red under 120, green over 150, blue over 200), scoring {!max_title_score}
    or less. Wherever the tile is, scrolled into view or not. *)

val title_score : Effects.measurements -> float option
(** The title's score, for a log line. *)

val max_title_score : float
(** 0.08: the title scores 0.034 at most (shifted too), other games' titles
    ("Legends: Z-A", "Brilliant Diamond") and HOME's own screens 0.156 at least.
*)

val tile : Effects.measurements -> int option
(** The first tile (0 the leftmost) scoring {!max_score} or less. *)

val max_score : float
(** 0.05. *)

val tile_color : Switch_home.Home_screen.tile_color
(** Pokémon HOME's teal "HOME" lettering, for the HOME menu reader that closes
    and starts it: about 0.16 of its tile's art, and up to 0.10 of others', too
    little to tell tiles apart (hence the template); the HOME menu reader's
    cursor and HOME detection do not use it. *)
