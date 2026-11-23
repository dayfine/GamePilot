(** Reader: the move menu's chosen move has no PP left. On the move menu the PP
    box shows the move under the cursor's "PP current/max" in a color for how
    much is left (pokefirered battle_message.c, GetCurrentPpToMaxPpState), red
    at 0. Ported from the fork's Dialogs/PokemonFRLG_BattleDialogs
    (BattleOutOfPpDetector, which the fork reads with the move menu up before
    the game says "There's no PP left for this move!"); its box, relative to the
    game picture.

    Unverified: no capture of a move at 0 PP yet. The captures at hand show only
    that full and partly spent PP (8/10, 19/20, 12/15, 9/15, 5/5 on mGBA; Switch
    move menus) does not read as empty. *)

val probes : Wire.probe_spec list

(** {1 Thresholds} *)

val min_red_share : float
(** Red ((180, 0, 0) to (255, 120, 120), around the fork's measured (225, 74,
    27)) covers more than this share of the PP line (the fork's 0.01). The
    game's PP palette (graphics/interface/text_pp.pal) draws 0 PP in (238, 0,
    0), inside the range; a quarter left is (255, 148, 0) and half (238, 222,
    0), both outside it. *)

(** {1 Reader} *)

val no_pp_left : Effects.measurements -> bool
(** The move menu shows, its PP in red. *)
