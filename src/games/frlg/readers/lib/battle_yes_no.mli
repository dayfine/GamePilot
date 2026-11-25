(** Reader: the YES/NO box of a battle, over the right end of the teal text box:
    "Delete a move to make room for ...?", "Stop learning ...?", "Use next
    POKéMON?". Ported from the fork's Dialogs/PokemonFRLG_BattleDialogs
    (BattleLearnDialogDetector: the white box beside the teal one) and
    battle_yes_no_shows (PokemonFRLG_BattleScreenDetector: the box's slate
    frame, so a white battle background, as in Misty's gym, is not taken for the
    box). The boxes are theirs, relative to the game picture.

    It reads the box, not the question: a trainer's "Will ... change POKéMON?"
    (the Shift battle style) shows the same box. *)

val probes : Wire.probe_spec list

(** {1 Thresholds} *)

val min_frame_share : float
(** The box's left frame, slate blue ((95, 90, 120) to (170, 175, 240): the
    fork's range around (120, 115, 145) and its lighter edge (147, 155, 218)),
    covers at least this share of a box 8 game pixels wide around it (x 184-192,
    y 70-104): the frame is 2 of those 8 pixels on nearly every row. Measured:
    0.35 with the box (Switch); at most 0.025 on battle captures without it,
    0.31 on an overworld (whose other edges fail). No mGBA capture with the box
    yet. *)

(** {1 Reader} *)

val yes_no_box : Effects.measurements -> bool
(** The white YES/NO box with its slate frame beside the teal text box. *)

val move_learn : Effects.measurements -> bool
(** The YES/NO box with the player's HP box beside it
    ({!Battle_screen.player_box_left}): a move to learn ("Delete a move ...?",
    "Stop learning ...?"), where "Use next POKéMON?" has the fainted battler's
    box gone. The box covers the HP box's right end, so the whole HP box never
    reads with it (Victory Road, mGBA, 2026-11-23: a move learn taken for "Use
    next" was answered NO and asked again for ever). *)
