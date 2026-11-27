(** Checkpoint program [bdsp.static_rng] for BDSP static legendary RNG
    manipulation (Workflow B) on the Switch.

    GamePilot's own program wiring {!Static_rng_options},
    {!Static_rng_workflow}, {!Bdsp_blink_rng.Munchlax_seed_finder},
    {!Bdsp_blink_rng.In_chamber_reidentifier},
    {!Bdsp_blink_rng.Static_rng_trigger},
    {!Bdsp_readers.Shiny_encounter_detector}, {!Bdsp_actions.Game_entry}, and
    {!Switch.Game_entry}. *)

type templates = {
  munchlax_eye_png : string;
      (** Raw PNG bytes of Munchlax's open eye on the intro screen. *)
  player_eye_png : string;
      (** Raw PNG bytes of the player's open eye in the legendary chamber. *)
  player_eye_box : Wire.box;
      (** Normalized ROI around the player's eye in the legendary chamber. *)
}
(** Eye-blink PNG templates and player eye ROI supplied by the CLI runner. *)

val default_player_eye_box : Wire.box
(** Default normalized player eye ROI in a Ramanas Park chamber. *)

val run :
  picture:Wire.box ->
  templates:templates ->
  ?options:Run_options.t ->
  unit ->
  bool * string
(** Runs [bdsp.static_rng] in the active effect session over [picture] with
    [templates] and checked [options]. Returns [(passed, summary_line)]. *)
