(** Checkpoint program [bdsp.static_rng] for BDSP Ramanas Park static legendary
    RNG manipulation (Workflow A) on the Switch.

    GamePilot's own program wiring {!Static_rng_options},
    {!Static_rng_workflow}, {!Pedestal_seed_finder},
    {!Bdsp_blink_rng.In_chamber_reidentifier},
    {!Bdsp_blink_rng.Static_rng_trigger},
    {!Bdsp_readers.Shiny_encounter_detector}, {!Bdsp_actions.Game_entry}, and
    {!Switch.Game_entry}. *)

type templates = {
  player_eye_png : string;
      (** Raw PNG bytes of the player's open eye facing South. *)
  player_eye_box : Wire.box;
      (** Normalized ROI around the player's eye at the pedestal and in the
          Mystery Space. *)
}
(** Player open-eye PNG template and ROI supplied by the CLI runner. *)

val default_player_eye_box : Wire.box
(** Default normalized player eye ROI covering both the Ramanas Park pedestal
    room and the Mystery Space. *)

val run :
  picture:Wire.box ->
  templates:templates ->
  ?options:Run_options.t ->
  unit ->
  bool * string
(** Runs [bdsp.static_rng] in the active effect session over [picture] with
    [templates] and checked [options]. Returns [(passed, summary_line)]. *)
