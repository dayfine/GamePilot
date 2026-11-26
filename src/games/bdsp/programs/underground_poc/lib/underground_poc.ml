module OW = Bdsp_actions.Bdsp_overworld
module MP = Bdsp_actions.Bdsp_mining_play
module B = Switch_home.Black_screen
module H = Switch_home.Held_screen
module P = Switch_home.Switch_presses
open Bdsp_underground

let ( let* ) = Result.bind
let default_state = ""
let native_picture : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. }
let goal = Mining_goal.ramanas_all_slates
let step_hold_ms = 340
let step_cooldown_ms = 120
let fade_timeout_ms = 8000
let dig_enter_fade_timeout_ms = 3500
let open_dlg_timeout_ms = 8000
let black_hold_ms = 80.
let clear_hold_ms = 200.
let post_open_wait_ms = 400
let post_dig_wait_ms = 1000
let minimap_probe_timeout_ms = 1000
let step_probe_timeout_ms = 400
let max_open_dialog_presses = 6
let max_end_dialog_presses = 15
let door_bounce_hold_ms = 2500
let north_hug_ms = 450
let east_align_ms = 2000
let south_return_ms = 3000
let west_return_ms = 2600
let sweep_steps = 12
let total_cycles = 15

let log msg =
  let line = "[bdsp.underground_poc] " ^ msg in
  Watch_report.log print_endline line

let is_black m = if B.shown m then Some () else None
let is_not_black m = if not (B.shown m) then Some () else None
let is_dialog m = if Bdsp_readers.Dialog_detector.shown m then Some () else None

let subscribe_corridor ~picture =
  ignore
    (Effects.subscribe
       (B.probes ~picture
       @ Bdsp_readers.Dialog_detector.probes ~picture
       @ Bdsp_readers.Battle_detector.probes ~picture
       @ Bdsp_readers.Minimap_sparkles.probes ~picture)
      : string list)

let read_nearby_sparkles ~picture =
  subscribe_corridor ~picture;
  match Effects.await ~timeout_ms:minimap_probe_timeout_ms (fun _ -> true) with
  | Effects.Holds m -> Bdsp_readers.Minimap_sparkles.read m
  | Effects.Timeout ->
      {
        Bdsp_readers.Minimap_sparkles.east_corridor = true;
        north_corridor = true;
      }

let play_entered_minigame ~picture ~counters =
  ignore
    (H.wait_for ~timeout_ms:fade_timeout_ms (H.held clear_hold_ms is_not_black)
      : unit option);
  ignore
    (H.wait_for ~timeout_ms:open_dlg_timeout_ms (H.held clear_hold_ms is_dialog)
      : unit option);
  let* () =
    OW.advance_dialog ~log ~picture ~max_presses:max_open_dialog_presses ()
  in
  P.wait post_open_wait_ms;
  let tally = Mining_counters.to_tally counters in
  let* moves, bailed = MP.dig_wall_smart ~log ~picture ~goal ~tally () in
  log (Printf.sprintf "Smart dig done: moves=%d bailed=%b" moves bailed);
  P.wait post_dig_wait_ms;
  let* () =
    OW.advance_dialog ~log ~picture ~max_presses:max_end_dialog_presses ()
  in
  ignore
    (H.wait_for ~timeout_ms:fade_timeout_ms (H.held clear_hold_ms is_not_black)
      : unit option);
  P.wait post_dig_wait_ms;
  let next = Mining_counters.record_dig counters ~bailed [] in
  log ("Counters: " ^ Mining_counters.format_summary ~goal next);
  Ok next

let enter_and_play_minigame ~picture ~counters =
  log "Prompt detected; confirming dig vs NPC dialog...";
  OW.interact ();
  match
    H.wait_for ~timeout_ms:dig_enter_fade_timeout_ms
      (H.held black_hold_ms is_black)
  with
  | Some () ->
      log "Dig fade detected! Entering minigame...";
      play_entered_minigame ~picture ~counters
  | None ->
      log "No dig fade (NPC dialog); dismissing with B...";
      let* () =
        OW.dismiss_dialog ~log ~picture ~max_presses:max_open_dialog_presses ()
      in
      Ok counters

let handle_step_event ~picture ~counters =
  match Effects.await ~timeout_ms:step_probe_timeout_ms (fun _ -> true) with
  | Effects.Holds m when Bdsp_readers.Battle_detector.shown m ->
      let* () = OW.run_from_battle ~log ~picture () in
      Ok (Mining_counters.record_battle_escaped counters)
  | Effects.Holds m when Bdsp_readers.Dialog_detector.shown m ->
      let* next = enter_and_play_minigame ~picture ~counters in
      subscribe_corridor ~picture;
      Ok next
  | _ -> Ok counters

let sweep_wall ~picture ~move_dir ~face_dir ~steps ~counters =
  subscribe_corridor ~picture;
  let move_btn = OW.button_of_dir move_dir in
  let rec loop left cur =
    if left <= 0 then Ok cur
    else (
      P.press ~hold_ms:step_hold_ms ~cooldown_ms:step_cooldown_ms move_btn;
      OW.turn face_dir;
      OW.interact ();
      let* next = handle_step_event ~picture ~counters:cur in
      loop (left - 1) next)
  in
  loop steps counters

let sweep_east_leg ~picture ~counters =
  log "Hugging North wall & sweeping East toward South-East corner...";
  OW.run_hold Corridor_nav.North ~hold_ms:north_hug_ms;
  sweep_wall ~picture ~move_dir:Corridor_nav.East ~face_dir:Corridor_nav.North
    ~steps:sweep_steps ~counters

let sweep_north_leg ~picture ~counters =
  log "Running East to corner & sweeping North along East wall...";
  OW.run_hold Corridor_nav.East ~hold_ms:east_align_ms;
  let* counters =
    sweep_wall ~picture ~move_dir:Corridor_nav.North ~face_dir:Corridor_nav.East
      ~steps:sweep_steps ~counters
  in
  log "Returning South to South-East corner...";
  OW.run_hold Corridor_nav.South ~hold_ms:south_return_ms;
  Ok counters

let sweep_targeted_corridors ~picture
    ~(sp : Bdsp_readers.Minimap_sparkles.nearby) ~counters =
  let* counters =
    if sp.east_corridor then sweep_east_leg ~picture ~counters else Ok counters
  in
  let* counters =
    if sp.north_corridor then sweep_north_leg ~picture ~counters
    else Ok counters
  in
  log "Returning West to Hideaway doorway...";
  OW.run_hold Corridor_nav.North ~hold_ms:north_hug_ms;
  OW.run_hold Corridor_nav.West ~hold_ms:west_return_ms;
  Ok counters

let run_one_cycle ~picture ~idx ~counters =
  log (Printf.sprintf "=== Cycle %d/%d ===" idx total_cycles);
  let* () =
    OW.bounce_doorway ~log ~picture
      ~anchor:{ Corridor_nav.enter_dir = West; exit_dir = East }
      ~hold_ms:door_bounce_hold_ms ()
  in
  let counters = Mining_counters.record_refresh counters in
  P.wait post_dig_wait_ms;
  let sp = read_nearby_sparkles ~picture in
  log
    (Printf.sprintf "Minimap sparkles: East=%b North=%b" sp.east_corridor
       sp.north_corridor);
  let* counters =
    if Bdsp_readers.Minimap_sparkles.any sp then
      sweep_targeted_corridors ~picture ~sp ~counters
    else (
      log "No nearby sparkles on minimap; skipping corridor sweep!";
      Ok (Mining_counters.record_skipped_corridor counters))
  in
  let counters = Mining_counters.record_cycle counters in
  log ("Counters: " ^ Mining_counters.format_summary ~goal counters);
  Ok counters

let run_se_loop () =
  let picture = native_picture in
  let rec cycle idx counters =
    if idx > total_cycles then Ok counters
    else
      let* next = run_one_cycle ~picture ~idx ~counters in
      cycle (idx + 1) next
  in
  cycle 1 Mining_counters.empty

let run ?state:_ () =
  match run_se_loop () with
  | Ok counters ->
      ( true,
        "bdsp.underground_poc: PASS ("
        ^ Mining_counters.format_summary ~goal counters
        ^ ")" )
  | Error e -> (false, "bdsp.underground_poc: FAIL " ^ e)
