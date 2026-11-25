(** Reader: which of the four whole tiles in view on the Switch's HOME menu is
    Pokémon HOME's. The lab script ([plza_claim_and_bank.sh] in the BDSPLab lab
    tools) moved the cursor along the tiles and read each title with tesseract;
    here each tile's art (the HOME menu reader's slots,
    {!Switch_home.Home_screen}) is searched for the middle of Pokémon HOME's art
    (240x200 from its tile, cut from console B's capture of 2026-11-24) by a
    [core.template_match@1] probe: 0.0067 at most on its tile, cursor on it or
    not, and 0.16 at least on the other games' tiles. *)

val probes : Effects.template_hash -> Wire.probe_spec list
(** The four tiles' probes, on the whole frame, with the art's template. *)

val tile : Effects.measurements -> int option
(** The first tile (0 the leftmost) scoring {!max_score} or less. *)

val max_score : float
(** 0.05. *)

val tile_color : Switch_home.Home_screen.tile_color
(** Pokémon HOME's teal "HOME" lettering, for the HOME menu reader that closes
    and starts it: about 0.16 of its tile's art, and up to 0.10 of others', too
    little to tell tiles apart (hence the template); the HOME menu reader's
    cursor and HOME detection do not use it. *)
