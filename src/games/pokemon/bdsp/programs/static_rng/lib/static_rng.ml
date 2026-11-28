module EBR = Bdsp_readers.Eye_blink_reader
module Opts = Static_rng_options
module WF = Static_rng_workflow

type templates = {
  player_eye_png : string;
  chamber_eye_png : string;
  player_eye_box : Wire.box;
  frame_dir : string option;
}

let default_player_eye_box : Wire.box =
  { x = 0.493; y = 0.672; w = 0.030; h = 0.044 }

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

let reid_cfg = { threshold = 0.20; search_min = 50; search_max = 10_000 }
let rgb_max = 255

let fallback_home_tile : Switch.Home_screen.tile_color =
  { min = (0, 0, 0); max = (rgb_max, rgb_max, rgb_max) }

let log_line msg = Effects.show_log msg
let submit_presses cmds = ignore (Effects.submit cmds : Wire.batch_done)

let dismiss_dialog () =
  submit_presses
    [
      Wire.press ~hold_ms:timings.press_ms
        ~cooldown_ms:timings.dialog_cooldown_ms [ Wire.B ];
      Wire.press ~hold_ms:timings.press_ms
        ~cooldown_ms:timings.dialog_cooldown_ms [ Wire.B ];
    ]

let freeze_player () =
  dismiss_dialog ();
  submit_presses
    [
      Wire.press ~hold_ms:timings.press_ms
        ~cooldown_ms:timings.wheel_cooldown_ms [ Wire.Plus ];
      Wire.press ~hold_ms:timings.press_ms ~cooldown_ms:timings.bike_cooldown_ms
        [ Wire.Right ];
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

let reidentify_with_bounds ~picture ~target ~base_state ~search_min ~search_max
    =
  let base =
    Bdsp_blink_rng.In_chamber_reidentifier.default_config ~picture ~target
      ~base_state
  in
  let bounds = { base.bounds with search_min; search_max } in
  Bdsp_blink_rng.In_chamber_reidentifier.run
    { base with bounds; threshold = reid_cfg.threshold }

let reidentify_in_chamber ~picture ~target ~base_state =
  reidentify_with_bounds ~picture ~target ~base_state
    ~search_min:reid_cfg.search_min ~search_max:reid_cfg.search_max

type frame_capture = { count : int; interval_s : int; ms_per_s : int }

let post_intro_frames = { count = 15; interval_s = 2; ms_per_s = 1000 }

let save_one_frame ~dir ~tag i =
  let sec = i * post_intro_frames.interval_s in
  let path =
    Filename.concat dir (Printf.sprintf "battle_%d_%02ds.png" tag sec)
  in
  ignore (Effects.save_frame path : int);
  if i + 1 < post_intro_frames.count then
    Switch.Switch_presses.wait
      (post_intro_frames.interval_s * post_intro_frames.ms_per_s)

let capture_frames_to ~picture dir =
  let tag = int_of_float (Effects.now ()) in
  let total_s = post_intro_frames.count * post_intro_frames.interval_s in
  log_line
    (Printf.sprintf "Saving %d battle frames (%ds) to %s (tag=%d)..."
       post_intro_frames.count total_s dir tag);
  let probes = Bdsp_readers.Battle_detector.probes ~picture in
  Effects.with_probes probes (fun () ->
      for i = 0 to post_intro_frames.count - 1 do
        save_one_frame ~dir ~tag i
      done)

let capture_post_intro_frames ~picture ~frame_dir () =
  match frame_dir with
  | None | Some "" -> ()
  | Some dir -> capture_frames_to ~picture dir

let detect_shiny ~picture ~frame_dir () =
  let reading = Bdsp_readers.Shiny_encounter_detector.detect ~picture () in
  capture_post_intro_frames ~picture ~frame_dir ();
  reading

let trigger_encounter ~picture ~chamber_eye_target ~on_phase cfg
    (anchor : Bdsp_blink_rng.In_chamber_reidentifier.anchor) =
  Trigger_wait.run ~picture ~log:log_line ~wall_now_ms:Watch_report.now_ms
    ~on_phase ~prepare_for_trigger
    ~reidentify_with_bounds:
      (reidentify_with_bounds ~picture ~target:chamber_eye_target
         ~base_state:anchor.base_state)
    cfg anchor

let live_game_steps ~picture ~frame_dir ~pedestal_eye_target ~chamber_eye_target
    : WF.game_steps =
  {
    log = log_line;
    show_counters = Watch_report.counters;
    freeze_player;
    recover_pedestal_seed =
      recover_pedestal_seed ~picture ~target:pedestal_eye_target;
    enter_chamber;
    reidentify_in_chamber =
      reidentify_in_chamber ~picture ~target:chamber_eye_target;
    trigger_encounter = trigger_encounter ~picture ~chamber_eye_target;
    detect_shiny = detect_shiny ~picture ~frame_dir;
    soft_reset_to_pedestal = soft_reset_to_pedestal ~picture;
  }

let run_checked ~picture ~templates cfg =
  let pedestal_template = Effects.upload_template templates.player_eye_png in
  let chamber_template =
    if String.equal templates.chamber_eye_png templates.player_eye_png then
      pedestal_template
    else Effects.upload_template templates.chamber_eye_png
  in
  let pedestal_eye_target : EBR.target =
    {
      id = "bdsp_eye_player";
      box = templates.player_eye_box;
      template = pedestal_template;
    }
  in
  let chamber_eye_target : EBR.target =
    {
      id = "bdsp_eye_chamber";
      box = templates.player_eye_box;
      template = chamber_template;
    }
  in
  let steps =
    live_game_steps ~picture ~frame_dir:templates.frame_dir ~pedestal_eye_target
      ~chamber_eye_target
  in
  WF.run ~steps cfg |> WF.outcome_to_result cfg

let run ~picture ~templates ?(options = Run_options.none) () =
  match Opts.of_run_options options with
  | Error e -> (false, "bdsp.static_rng: invalid options: " ^ e)
  | Ok cfg -> run_checked ~picture ~templates cfg

let run_with_loaded ~log ~picture ~options
    (loaded : Bdsp_checkpoint_series.Static_rng_templates.loaded) =
  let templates =
    {
      player_eye_png = loaded.player_eye_png;
      chamber_eye_png = loaded.chamber_eye_png;
      player_eye_box = default_player_eye_box;
      frame_dir = loaded.frame_dir;
    }
  in
  let passed, line = run ~picture ~templates ~options () in
  log line;
  if passed then Ok ()
  else Error (Engine_run.Failure.cause ~repeats:true "static_rng_failed" line)

let run_action ~log ~picture ~options =
  match Bdsp_checkpoint_series.Static_rng_templates.load () with
  | Error msg ->
      Error (Engine_run.Failure.cause ~repeats:false "static_rng_templates" msg)
  | Ok loaded -> run_with_loaded ~log ~picture ~options loaded
