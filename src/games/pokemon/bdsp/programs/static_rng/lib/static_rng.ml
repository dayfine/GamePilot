module EBR = Bdsp_readers.Eye_blink_reader
module Opts = Static_rng_options
module WF = Static_rng_workflow

type templates = { player_eye_png : string; player_eye_box : Wire.box }

let default_player_eye_box : Wire.box =
  { x = 0.470; y = 0.665; w = 0.058; h = 0.056 }

type chamber_timings = {
  press_ms : int;
  dialog_cooldown_ms : int;
  slate_cooldown_ms : int;
  wheel_cooldown_ms : int;
  bike_cooldown_ms : int;
  warp_wait_ms : int;
  walk_up_ms : int;
  walk_cooldown_ms : int;
  slate_a_presses : int;
  slate_b_presses : int;
}

let timings =
  {
    press_ms = 120;
    dialog_cooldown_ms = 500;
    slate_cooldown_ms = 1500;
    wheel_cooldown_ms = 700;
    bike_cooldown_ms = 900;
    warp_wait_ms = 8000;
    walk_up_ms = 2200;
    walk_cooldown_ms = 300;
    slate_a_presses = 4;
    slate_b_presses = 5;
  }

type reid_defaults = { threshold : float; search_min : int; search_max : int }

let reid_cfg = { threshold = 0.08; search_min = 50; search_max = 10_000 }
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

let submit_presses cmds = ignore (Effects.submit cmds : Wire.batch_done)

let freeze_player () =
  submit_presses
    [
      Wire.press ~hold_ms:timings.press_ms
        ~cooldown_ms:timings.wheel_cooldown_ms [ Wire.Plus ];
      Wire.press ~hold_ms:timings.press_ms ~cooldown_ms:timings.bike_cooldown_ms
        [ Wire.Right ];
    ]

let dismiss_dialog () =
  submit_presses
    [
      Wire.press ~hold_ms:timings.press_ms
        ~cooldown_ms:timings.dialog_cooldown_ms [ Wire.B ];
      Wire.press ~hold_ms:timings.press_ms
        ~cooldown_ms:timings.dialog_cooldown_ms [ Wire.B ];
    ]

let repeat_press button count cooldown_ms =
  List.init count (fun _ ->
      Wire.press ~hold_ms:timings.press_ms ~cooldown_ms [ button ])

let enter_chamber () =
  dismiss_dialog ();
  Bdsp_actions.Overworld_actions.turn North;
  submit_presses
    (repeat_press Wire.A timings.slate_a_presses timings.slate_cooldown_ms
    @ repeat_press Wire.B timings.slate_b_presses timings.slate_cooldown_ms);
  Switch.Switch_presses.wait timings.warp_wait_ms;
  submit_presses
    [
      Wire.press ~hold_ms:timings.walk_up_ms
        ~cooldown_ms:timings.walk_cooldown_ms [ Wire.Up ];
    ];
  Bdsp_actions.Overworld_actions.turn South;
  freeze_player ();
  Ok ()

let prepare_for_trigger () =
  dismiss_dialog ();
  Bdsp_actions.Overworld_actions.turn North

let soft_reset_to_pedestal ~picture () =
  let ( let* ) = Result.bind in
  let* () =
    Switch.Game_entry.close_game ~log:log_line ~picture fallback_home_tile
  in
  let* () =
    Switch.Game_entry.start_game ~log:log_line ~picture ~game_slot:0
      ~user_slot:0 fallback_home_tile
  in
  Bdsp_actions.Game_entry.openedgame_to_ingame ~log:log_line ~picture ()

let recover_pedestal_seed ~picture ~target ~timeout_s =
  let base = Pedestal_seed_finder.default_config ~picture ~target in
  Pedestal_seed_finder.run
    { base with timeout_seconds = float_of_int timeout_s }

let reidentify_in_chamber ~picture ~target ~base_state =
  let base =
    Bdsp_blink_rng.In_chamber_reidentifier.default_config ~picture ~target
      ~base_state
  in
  let bounds =
    {
      base.bounds with
      search_min = reid_cfg.search_min;
      search_max = reid_cfg.search_max;
    }
  in
  Bdsp_blink_rng.In_chamber_reidentifier.run
    { base with bounds; threshold = reid_cfg.threshold }

let detect_shiny ~picture () =
  Bdsp_readers.Shiny_encounter_detector.detect ~picture ()

let live_game_steps ~picture ~player_eye_target : WF.game_steps =
  {
    log = log_line;
    update_counters = publish_counters;
    freeze_player;
    recover_pedestal_seed =
      recover_pedestal_seed ~picture ~target:player_eye_target;
    enter_chamber;
    reidentify_in_chamber =
      reidentify_in_chamber ~picture ~target:player_eye_target;
    prepare_for_trigger;
    trigger_encounter = Bdsp_blink_rng.Static_rng_trigger.run;
    detect_shiny = detect_shiny ~picture;
    soft_reset_to_pedestal = soft_reset_to_pedestal ~picture;
  }

let run_checked ~picture ~templates cfg =
  let player_template = Effects.upload_template templates.player_eye_png in
  let player_eye_target : EBR.target =
    {
      id = "bdsp_eye_player";
      box = templates.player_eye_box;
      template = player_template;
    }
  in
  let steps = live_game_steps ~picture ~player_eye_target in
  WF.run ~steps cfg |> WF.outcome_to_result cfg

let run ~picture ~templates ?(options = Run_options.none) () =
  match Opts.of_run_options options with
  | Error e -> (false, "bdsp.static_rng: invalid options: " ^ e)
  | Ok cfg -> run_checked ~picture ~templates cfg
