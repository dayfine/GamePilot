(** Reader: PLZA's tile on the Switch's HOME menu. The cursor is on it when
    HOME's title row reads "Pokémon Legends: Z-A": the fork OCRs the row and
    checks it ends in "za" (PokemonLZA_AutoStoryIntroScreens.cpp); here
    {!Switch_home.Home_title} searches the row for its "Legends: Z-A"
    ({!title_template}). *)

val title_template : string
(** ["src/games/pokemon/plza/assets/switch-home-title-legends-za.png"], from the
    repo root: "Legends: Z-A", 282x50 at (337, 218) of console B's HOME with the
    cursor on PLZA's first tile (2026-11-25). "Pokémon" alone would match every
    title. *)

val title_id : string
(** ["plza.home_title"]. *)

val probes : title:Effects.template_hash -> Wire.probe_spec list
(** The title's probe, on the whole frame, with the uploaded template. *)

val on_plza_tile : Effects.measurements -> bool
(** The title scores {!Switch_home.Home_title.max_score} (0.08) or less: 0.038
    at most on console B's HOME with the cursor on PLZA's tile, the row scrolled
    or not, shifted too; 0.112 at least with it on another tile (Pokémon HOME,
    Brilliant Diamond, FireRed, Let's Go, Pikachu!) and on HOME's other screens.
*)

val tile_color : Switch_home.Home_screen.tile_color
(** PLZA's tile colour for the HOME reader: cyan-ish, red 0 to 120, green and
    blue 120 to 255. A guess, not measured: the HOME reader's cursor and HOME
    detection do not need it. *)
