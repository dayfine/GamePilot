(** Reader: the red arrow at the end of a battle message, which says the page is
    done and waits for A or B. Ported from the fork's
    Dialogs/PokemonFRLG_BattleDialogs (AdvanceBattleDialogDetector): one
    [core.color_count@1] probe over the text box, as the fork filters it to the
    arrow's red; its box, relative to the game picture. The text box itself is
    {!Battle_screen.battle_text_box}. Battle text is white with a grey shadow,
    so nothing else in the box is in range. Not for Japanese, whose box sits
    elsewhere (the fork has a second box for it). *)

val probes : Wire.probe_spec list

(** {1 Thresholds} *)

val min_red_excess : float
(** The text box's pixels in the arrow's range ((164, 0, 0) to (255, 114, 87),
    the fork's) have a mean red more than this above both green and blue (the
    fork's 180). Measured: 212-234 with the arrow on Switch, 255 on mGBA; a
    battle text box without one has no pixel in range, and the reddest non-arrow
    in the captures (a party list's) is 134. *)

(** {1 Reader} *)

val advance_arrow : Effects.measurements -> bool
(** The battle text box with the red arrow, also under a level-up box (which
    covers the text box's right edge, so {!Battle_screen.battle_text_box} does
    not read there). *)
