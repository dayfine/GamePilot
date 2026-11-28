(** Checkpoint program [bdsp.static_rng] for BDSP static legendary RNG
    manipulation on the Switch.

    Supports both Ramanas Park slate-chamber legendaries
    ({!Bdsp_rng.Static_targets.Ramanas_slate_chamber}, running the [0PK -> 1PK]
    pedestal-to-chamber workflow) and Sinnoh standing static encounters
    ({!Bdsp_rng.Static_targets.Standing_at_encounter}, skipping slate insertion
    and chamber re-identification to trigger directly from the saved spot). New
    static targets and locations plug in through {!Bdsp_rng.Static_targets.all}
    and {!Static_rng_workflow} without changing this program entry point.

    GamePilot's own program wiring {!Static_rng_options},
    {!Static_rng_workflow}, {!Pedestal_seed_finder},
    {!Bdsp_blink_rng.In_chamber_reidentifier},
    {!Bdsp_blink_rng.Static_rng_trigger},
    {!Bdsp_readers.Shiny_encounter_detector}, {!Bdsp_actions.Game_entry}, and
    {!Switch.Game_entry}. *)

type templates = {
  player_eye_png : string;
      (** Raw PNG bytes of the player's open eye facing South at the pedestal.
      *)
  chamber_eye_png : string;
      (** Raw PNG bytes of the player's open eye inside the Mystery Space
          (defaults to [player_eye_png] when room lighting matches). *)
  player_eye_box : Wire.box;
      (** Normalized ROI around the player's eye at the pedestal and in the
          Mystery Space. *)
  frame_dir : string option;
      (** Optional directory for saving 30 s of post-intro battle frames. *)
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

val run_action :
  log:(string -> unit) ->
  picture:Wire.box ->
  options:Run_options.t ->
  (unit, Engine_run.Failure.cause) result
(** Loads eye templates via {!Bdsp_checkpoint_series.Static_rng_templates.load}
    and runs [bdsp.static_rng] as a checkpoint action, returning an
    {!Engine_run.Failure.cause} on missing templates or an exhausted hunt. *)
