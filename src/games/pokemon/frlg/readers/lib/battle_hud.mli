(** Reader: FireRed/LeafGreen wild-battle HUD probes for the foe and player HP
    bars and the foe's major status badge.

    GamePilot's own reader (not in the fork): uses 12 segmented
    [core.color_stats@1] probes across each 48-pixel GBA HP bar and one
    [core.color_stats@1] probe over the 20x8 GBA foe status icon slot
    ([pokefirered] [src/battle_interface.c],
    [graphics/interface/status_icons.pal]). Because the status badge is
    classified from its palette color rather than text, it is independent of
    game language.

    All three readers are gated by {!Battle_screen.foe_box} or
    {!Battle_screen.player_box}, so callers must subscribe
    {!Battle_screen.probes} alongside {!probes}. *)

(** Observed major status condition on the wild foe's HP box. *)
type foe_status =
  | Healthy  (** Cream HP box background with no status badge. *)
  | Asleep  (** Silver/grey [SLP] badge. *)
  | Paralyzed  (** Yellow [PAR] badge. *)
  | Other_status  (** Purple [PSN], orange-red [BRN], or cyan [FRZ] badge. *)

val probes : Wire.probe_spec list
(** The 25 HUD probes (12 foe HP segments, 12 player HP segments, and 1 foe
    status badge) in GBA picture coordinates. *)

val foe_hp_ratio : Effects.measurements -> float option
(** Estimated wild foe HP fraction in [0.0 .. 1.0] across the 48-pixel GBA foe
    HP bar, or [None] when {!Battle_screen.foe_box} is absent or no foe HP
    segment probes are present in the frame. *)

val player_hp_ratio : Effects.measurements -> float option
(** Estimated active player HP fraction in [0.0 .. 1.0] across the 48-pixel GBA
    player HP bar, or [None] when {!Battle_screen.player_box} is absent or no
    player HP segment probes are present in the frame. *)

val foe_status : Effects.measurements -> foe_status option
(** Classified major status on the wild foe's HP box, or [None] when
    {!Battle_screen.foe_box} is absent or the status probe is missing from the
    frame. *)

val foe_asleep : Effects.measurements -> bool option
(** [Some true] when {!foe_status} is [Some Asleep], [Some false] for any other
    status reading, or [None] when {!foe_status} is [None]. *)
