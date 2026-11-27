(** Pure visual-only state machine for FireRed/LeafGreen wild battle-intro shiny
    detection.

    GamePilot's own reader (modeled on BDSP's visual battle-intro detector in
    [Bdsp_readers.Shiny_encounter_reader], because GamePilot's daemon is
    video-only with no audio probe).

    In FireRed/LeafGreen, when a wild battle opens, the teal battle text box
    ("Wild X appeared!") and the foe HP box appear while the wild Pokémon slides
    in and plays its cry. If the wild Pokémon is shiny, the sparkle animation
    adds roughly 1.1 to 1.3 seconds before the red text-advance arrow (or player
    send-out / action menu) appears. This state machine measures that visual
    wild-intro duration and classifies it against {!thresholds} before turn 1 so
    automation can skip catch turns and balls on an RNG miss.

    The default timing window in {!default_thresholds} is an initial visual
    estimate to be verified against live mGBA and Switch shiny captures. *)

(** Phase of an FRLG wild battle opening tracked from screen probes. *)
type phase =
  | Before_battle
      (** Waiting for the battle text box or foe HP box to appear. *)
  | Wild_appearance
      (** Wild Pokémon cry and optional shiny sparkle animation in progress. *)
  | Intro_complete  (** Advance arrow, player HP box, or action menu reached. *)

(** Visual-only shiny verdict for the wild encounter. *)
type verdict =
  | Shiny  (** Wild-intro duration fell within the shiny delay window. *)
  | Not_shiny  (** Wild-intro duration fell outside the shiny delay window. *)
  | Unknown
      (** Intro did not finish, or watching started after the intro had already
          ended. *)

type thresholds = {
  shiny_delay_ms : float;
      (** Expected wild-intro duration in ms when shiny (default 2800). *)
  min_margin_ms : float;
      (** Allowed margin below [shiny_delay_ms] in ms (default 500). *)
  max_margin_ms : float;
      (** Allowed margin above [shiny_delay_ms] in ms (default 900). *)
}
(** Timing window for classifying the wild-intro duration. *)

type reading = {
  verdict : verdict;  (** Classified shiny verdict for the wild encounter. *)
  wild_intro_ms : float option;
      (** Measured duration in ms from the first battle text box / foe HP box
          appearing to the advance arrow, player HP box, or action menu. *)
  phase : phase;  (** Encounter phase reached when watching ended. *)
}
(** Summary produced once the wild intro completes or watching times out. *)

type state
(** Immutable tracker state advanced one frame at a time by {!step}. *)

val default_thresholds : thresholds
(** Default FRLG wild-intro shiny timing window: 2800 ms (-500 / +900 ms, i.e.
    2300..3700 ms). *)

val probes : Wire.probe_spec list
(** Combined probes for {!Battle_screen} and {!Battle_text_arrow}. *)

val init : state
(** Fresh tracker state in {!Before_battle}. *)

val is_finished : state -> bool
(** [true] once {!Intro_complete} has been reached. *)

val step_signals :
  t_ms:float ->
  battle_text:bool ->
  foe_box:bool ->
  advance_arrow:bool ->
  player_box:bool ->
  battle_menu:bool ->
  state ->
  state
(** Advances [state] from pre-evaluated boolean signals at timestamp [t_ms]. *)

val step : frame:Effects.measurements -> state -> state
(** Advances [state] from one probe frame using {!Battle_screen} and
    {!Battle_text_arrow}. *)

val classify : ?thresholds:thresholds -> state -> reading
(** Classifies [state] into a {!reading} using [thresholds] (defaults to
    {!default_thresholds}). *)

val verdict_to_string : verdict -> string
(** Short lowercase name of a verdict ([shiny], [not_shiny], [unknown]). *)

val format_reading : reading -> string
(** One-line human-readable summary of a {!reading} for logs. *)
