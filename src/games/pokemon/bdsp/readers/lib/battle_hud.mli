(** Reader: BDSP wild-battle HUD probes for HP bars, foe Sleep badge, and
    forced-switch party screen detection.

    GamePilot's own reader (not in the fork): uses segmented [color_stats]
    probes along the foe and player HP bars plus color-distance checks for the
    foe's Sleep status pill and the forced-switch party screen banner. Because
    the Sleep pill is identified by its slate-violet badge color rather than
    text, it does not depend on game language (e.g. [SLP] vs [睡眠]).

    The 16:9 normalized probe boxes are initial BDSP HUD coordinates to be
    calibrated against a live non-shiny encounter. *)

(** High-level battle screen classification from the subscribed HUD probes. *)
type screen =
  | Action_menu  (** Main wild-battle Fight/Pokémon/Bag/Run menu is visible. *)
  | Forced_switch  (** Party switch-in screen is open after a faint. *)
  | Dialog  (** Short white battle dialog box is showing. *)
  | Black  (** Solid black transition screen. *)
  | Other  (** Animation, transition, or unrecognized screen. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** All HUD probes needed by {!foe_hp_ratio}, {!player_hp_ratio}, {!foe_asleep},
    and {!forced_switch_shown}, relative to [picture]. *)

val all_battle_probes : picture:Wire.box -> Wire.probe_spec list
(** {!probes} combined with {!Battle_detector.probes},
    {!Dialog_detector.probes}, and {!Switch.Black_screen.probes} for
    {!classify_screen}. *)

val foe_hp_ratio : Effects.measurements -> float option
(** Estimated wild foe HP ratio in [0.0 .. 1.0] from the 10-segment foe HP bar,
    or [None] when the HP bar probes are absent from the frame. *)

val player_hp_ratio : Effects.measurements -> float option
(** Estimated active player HP ratio in [0.0 .. 1.0] from the 10-segment player
    HP bar, or [None] when the HP bar probes are absent from the frame. *)

val foe_asleep : Effects.measurements -> bool option
(** [Some true] when the foe's Sleep status pill color is present on the foe
    HUD, [Some false] when the probe is present and does not match Sleep, or
    [None] when the probe is absent from the frame. *)

val forced_switch_shown : Effects.measurements -> bool
(** [true] when the forced-switch party screen's cyan-teal header bar is
    visible. *)

val classify_screen : Effects.measurements -> screen
(** Classify the current frame into a {!screen} using {!Battle_detector},
    {!forced_switch_shown}, {!Dialog_detector}, and {!Switch.Black_screen}. *)
