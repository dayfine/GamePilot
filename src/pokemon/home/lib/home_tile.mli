(** Reader: whether the cursor is on Pokémon HOME's tile on the Switch's HOME
    menu, by the title over the row ({!Switch_home.Home_title}), and which of
    the four whole tiles in view is HOME's, by its art. Each tile's art (the
    HOME menu reader's slots, {!Switch_home.Home_screen}) is searched for the
    middle of Pokémon HOME's art (240x200 from its tile, cut from console B's
    capture of 2026-11-24) by a [core.template_match@1] probe: 0.0067 at most on
    its tile, cursor on it or not, and 0.16 at least on the other games' tiles.
*)

val probes :
  art:Effects.template_hash ->
  title:Effects.template_hash ->
  Wire.probe_spec list
(** The title's probe and the four tiles' probes, on the whole frame, with the
    art's and the title's templates. *)

val on_home_tile : Effects.measurements -> bool
(** The cursor is on Pokémon HOME's tile: {!Switch_home.Home_title} finds a
    template of "Pokémon HOME"'s "HOME" (cut from console B's capture of
    2026-11-24, 142x48 at (414, 218)) on HOME's title row, wherever the tile is,
    scrolled into view or not: 0.034 at most (shifted too), other games' titles
    ("Legends: Z-A", "Brilliant Diamond", "Let's Go, Pikachu!" over a scrolled
    row with HOME's tile in view) and HOME's own screens 0.143 at least, against
    {!Switch_home.Home_title.max_score} (0.08). *)

val tile : Effects.measurements -> int option
(** The first tile (0 the leftmost) scoring {!max_score} or less. *)

val max_score : float
(** 0.05. *)

val tile_color : Switch_home.Home_screen.tile_color
(** Pokémon HOME's teal "HOME" lettering, for the HOME menu reader that closes
    and starts it: about 0.16 of its tile's art, and up to 0.10 of others', too
    little to tell tiles apart (hence the template); the HOME menu reader's
    cursor and HOME detection do not use it. *)
