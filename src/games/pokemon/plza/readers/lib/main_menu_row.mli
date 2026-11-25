(** Reader: which of the main menu's six rows (X: Boxes, Satchel, Pokédex, ...,
    Link Play last) is highlighted, and which of the six party cards on its
    right hold a Pokémon. Ported from [plza_claim_and_bank.sh] in the BDSPLab
    lab tools (console B, 2026-11-20), its [menu_row] test: row r's band (x 0.06
    to 0.32, y 0.265 + 0.117 r ± 0.025) is the highlighted one when it is the
    whitest band (every channel over 220) and over 0.45 white. The script read
    the bands with numpy; here one [core.color_count@1] probe a band. A white
    fade and a white text box also have a white band, so the menu must show as
    well ({!Main_menu.shown}: its right arrow and B button).

    New here: the party cards. Card k's HP bar is the strip (884 + 162 k, 394,
    110, 12) of the 1080p frame; a card with a Pokémon at full HP shows it green
    (green over 140 and over red and blue by 60, as {!Party_slots} reads the
    overworld bar's), an empty card shows none. Measured on the one full-size
    menu capture (tutorial-cards' it-menu-no-card: five cards 1.00 green, the
    empty sixth 0.00). *)

val rows : int
(** 6. *)

val probes : picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** {!Main_menu}'s, the six bands' and the six HP bars' probes, for a game
    picture at [picture] in the frame. *)

val highlighted : Effects.measurements -> int option
(** The highlighted row, 0 the top; [None] when the main menu does not show, no
    band is over 0.45 white or a probe is missing. *)

val white_shares : Effects.measurements -> float list
(** Each band's white share, top first (0 for a missing probe). *)

val green_shares : Effects.measurements -> float list
(** Each card's HP bar's green share, left first (0 for a missing probe). *)

val card_green : Effects.measurements -> int -> bool
(** Card [k] (0 the first) shows a green HP bar: half its strip green. *)

val card_empty : Effects.measurements -> int -> bool
(** Card [k] shows no HP bar: under 0.05 of its strip green. A Pokémon whose bar
    is yellow or red also reads so; the steps that use it read a fresh gift's
    card, at full HP. *)
