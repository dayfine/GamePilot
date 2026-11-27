module EBR = Bdsp_readers.Eye_blink_reader
module Opts = Static_rng_options
module WF = Static_rng_workflow

type templates = {
  munchlax_eye_png : string;
  player_eye_png : string;
  player_eye_box : Wire.box;
}

let default_player_eye_box : Wire.box =
  { x = 0.48; y = 0.42; w = 0.04; h = 0.06 }

let rgb_max = 255

let fallback_home_tile : Switch.Home_screen.tile_color =
  { min = (0, 0, 0); max = (rgb_max, rgb_max, rgb_max) }

let log_line msg = Effects.show_log msg

let publish_counters ~attempt ~max_attempts ~phase =
  Effects.show_counters
    [
      {
        Wire.Watch.label = "Attempt";
        value = Printf.sprintf "%d/%d" attempt max_attempts;
      };
      { Wire.Watch.label = "Phase"; value = phase };
    ]

let soft_reset_switch ~picture () =
  match
    Switch.Game_entry.close_game ~log:log_line ~picture fallback_home_tile
  with
  | Error e -> Error e
  | Ok () ->
      Switch.Game_entry.start_game ~log:log_line ~picture ~game_slot:0
        ~user_slot:0 fallback_home_tile

let recover_boot_seed ~picture ~template ~timeout_s =
  let base =
    Bdsp_blink_rng.Munchlax_seed_finder.default_config ~picture ~template
  in
  Bdsp_blink_rng.Munchlax_seed_finder.run
    { base with timeout_seconds = float_of_int timeout_s }

let enter_save ~picture () =
  Bdsp_actions.Game_entry.openedgame_to_ingame ~log:log_line ~picture ()

let reidentify_in_chamber ~picture ~target ~base_state =
  let cfg =
    Bdsp_blink_rng.In_chamber_reidentifier.default_config ~picture ~target
      ~base_state
  in
  Bdsp_blink_rng.In_chamber_reidentifier.run cfg

let detect_shiny ~picture () =
  Bdsp_readers.Shiny_encounter_detector.detect ~picture ()

let live_game_steps ~picture ~munchlax_template ~player_eye_target :
    WF.game_steps =
  {
    log = log_line;
    update_counters = publish_counters;
    recover_boot_seed = recover_boot_seed ~picture ~template:munchlax_template;
    enter_save = enter_save ~picture;
    reidentify_in_chamber =
      reidentify_in_chamber ~picture ~target:player_eye_target;
    trigger_encounter = Bdsp_blink_rng.Static_rng_trigger.run;
    detect_shiny = detect_shiny ~picture;
    soft_reset = soft_reset_switch ~picture;
  }

let run_checked ~picture ~templates cfg =
  let munchlax_template = Effects.upload_template templates.munchlax_eye_png in
  let player_template = Effects.upload_template templates.player_eye_png in
  let player_eye_target : EBR.target =
    {
      id = "bdsp_eye_player";
      box = templates.player_eye_box;
      template = player_template;
    }
  in
  let steps = live_game_steps ~picture ~munchlax_template ~player_eye_target in
  WF.run ~steps cfg |> WF.outcome_to_result cfg

let run ~picture ~templates ?(options = Run_options.none) () =
  match Opts.of_run_options options with
  | Error e -> (false, "bdsp.static_rng: invalid options: " ^ e)
  | Ok cfg -> run_checked ~picture ~templates cfg
