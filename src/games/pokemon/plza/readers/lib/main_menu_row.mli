(** Reader: which of the main menu's six rows (X: Boxes, Satchel, Pokédex, ...,
    Link Play last) is highlighted, and which of the six party cards on its
    right hold a Pokémon, measured on console B (2026-11-20). Row r's band (x
    0.06 to 0.32, y 0.265 + 0.117 r ± 0.025) is the highlighted one when it is
    the whitest band (every channel over 220) and over 0.45 white, read by one
    [core.color_count@1] probe a band. A white fade and a white text box also
    have a white band, so the menu must show as well ({!Main_menu.shown}: its
    right arrow and B button).

    The party cards: card k's HP bar is the strip (884 + 162 k, 394, 110, 12) of
    the 1080p frame; a card with a Pokémon at full HP shows it green (green over
    140 and over red and blue by 60, as {!Party_slots} reads the overworld
    bar's), an empty card shows none. Measured on the one full-size menu capture
    (tutorial-cards' it-menu-no-card: five cards 1.00 green, the empty sixth
    0.00).

    The sixth row (Link Play, 通信で遊ぶ in Japanese) shows only once Mable's
    research reward is claimed (03.15-mable-reward); before, the menu has five
    rows. Whether its button is drawn is read, not its name, so any language
    reads the same: the button's left and right edges (x 96 and 672 of the 1080p
    frame) are sharp steps from the menu's panel, measured in a strip above the
    name (y 870 to 896) as the brightness 8 px inside each edge less that 8 px
    outside, the two averaged. The button shows at a step of 13 or more: about
    20 unhighlighted and 180 highlighted at its end (console B, 2026-11-25); the
    bare panel has faint edges of its own there, under 7.5 on the five-row
    menus, a six-row menu still sliding in and the four-row Italian one. *)

val rows : int
(** 6. *)

val probes : picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** {!Main_menu}'s, the six bands', the sixth row's edges' and the six HP bars'
    probes, for a game picture at [picture] in the frame. *)

val link_play_probes : picture:Wire.box -> Wire.probe_spec list
(** The six bands' probes and the sixth row's edges': with {!Main_menu}'s
    subscribed (as the story's screen read has them), enough for {!highlighted}
    and {!link_play_shown}. *)

val highlighted : Effects.measurements -> int option
(** The highlighted row, 0 the top; [None] when the main menu does not show, no
    band is over 0.45 white or a probe is missing. *)

val link_play_step : Effects.measurements -> float option
(** The sixth row's edge step, as above; [None] when a probe is missing. *)

val link_play_shown : Effects.measurements -> bool
(** The main menu shows ({!highlighted}) with its sixth row's button: an edge
    step of 13 or more. A read just after X can come while the menu slides in,
    its sixth row not yet drawn: a caller gives it time. *)

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
