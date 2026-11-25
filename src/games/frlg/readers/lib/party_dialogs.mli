(** Readers: the windows the party menu opens over itself while an item is used
    on a member: a Rare Candy's level-up stats window, and the YES/NO box of
    "Should a move be deleted and replaced with ...?" and "Stop trying to teach
    ...?". Ported from the fork's Inference/Dialogs/PokemonFRLG_PartyDialogs.cpp
    (its level-up and move-learn detectors; English only, as GamePilot reads
    English games); the boxes are theirs, relative to the game picture. Each
    window is a grey border ((120, 115, 140)) around a white inside, tested
    along its top and right edges.

    The stats window is pokefirered's [sLevelUpStatsWindowTemplate]
    (party_menu.c, tiles 19-29 across, 1-12 down): page 1 prints each stat's
    rise ("+3"), page 2 the new totals, whose numbers leave the "+" column
    white. The YES/NO box is [sPartyMenuYesNoWindowTemplate] (tiles 21-27,
    9-13); it reads the box, not the question, so "Should a move be deleted
    ...?" and "Stop trying to teach ...?" read alike.

    Checked on the fork's Switch captures (CommandLineTests PartyLevelUpReader,
    page 2, and TeachScreenReader's two questions, from a TM). No capture of
    page 1 and no mGBA frame of either window yet. *)

val probes : Wire.probe_spec list

(** {1 Thresholds} *)

val max_border_distance : float
(** The border's channel shares lie within this of (120, 115, 140)'s: 0.25, the
    fork's. *)

val max_border_stddev_sum : float
(** ...and it is flat: 20, the fork's. *)

(** {1 Readers} *)

val level_up_box : Effects.measurements -> bool
(** The level-up stats window shows, either page. *)

val level_up_page : Effects.measurements -> int option
(** Which page: 1 (each stat's rise) or 2 (the totals); [None] without the
    window. *)

val move_learn_box : Effects.measurements -> bool
(** The party menu's YES/NO box: a move to learn, or to stop teaching. Where it
    differs: the overworld's YES/NO (the save question) is the same window in
    the same place and passes the fork's test, so the party's teal page
    background must show left of the boxes too (the colour of the fork's party
    selection detector, in the same PokemonFRLG_PartyDialogs.cpp, its box raised
    above the message box). *)
