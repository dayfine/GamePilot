module OW = Bdsp_actions.Bdsp_overworld
module MP = Bdsp_actions.Bdsp_mining_play
module US = Bdsp_readers.Underground_screen
module MS = Bdsp_readers.Minimap_sparkles
module H = Switch_home.Held_screen
module P = Switch_home.Switch_presses
open Bdsp_underground

let ( let* ) = Result.bind
let default_state = ""
let native_picture : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. }
let default_cycles = 15
let default_slates = 14
let step_hold_ms = 340
let step_cooldown_ms = 120
let fade_timeout_ms = 8000
let dig_enter_fade_timeout_ms = 3500
let open_dlg_timeout_ms = 8000
let black_hold_ms = 80.
let clear_hold_ms = 200.
let post_open_wait_ms = 400
let post_dig_wait_ms = 1000
let screen_probe_timeout_ms = 1000
let step_probe_timeout_ms = 400
let max_open_dialog_presses = 6
let max_end_dialog_presses = 15
let door_bounce_hold_ms = 2500
let north_hug_ms = 450
let east_align_ms = 2000
let north_run_ms = 2800
let south_return_ms = 3000
let west_return_ms = 2600
let sweep_steps = 12
let bag_open_wait_ms = 1400
let bag_scroll_pages = 5
let bag_page_rows = 6
let bag_nav_hold_ms = 80
let bag_nav_cooldown_ms = 140
let bag_page_wait_ms = 1200
let bag_exit_presses = 4
let bag_exit_cooldown_ms = 700

let log msg =
  let line = "[bdsp.underground_poc] " ^ msg in
  Watch_report.log print_endline line

let is_black m =
  match (US.read m).fade with Screen_state.Fade.Black -> Some () | _ -> None

let is_not_black m =
  match (US.read m).fade with Screen_state.Fade.Black -> None | _ -> Some ()

let is_dialog m = if (US.read m).dialog then Some () else None

let subscribe_screen ~picture =
  ignore (Effects.subscribe (US.probes ~picture) : string list)

let read_screen ~picture =
  subscribe_screen ~picture;
  match Effects.await ~timeout_ms:screen_probe_timeout_ms (fun _ -> true) with
  | Effects.Holds m -> Some (US.read m)
  | Effects.Timeout -> None

let play_entered_minigame ~picture ~goal ~counters =
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
  subscribe_screen ~picture;
  ignore
    (H.wait_for ~timeout_ms:fade_timeout_ms (H.held clear_hold_ms is_not_black)
      : unit option);
  P.wait post_dig_wait_ms;
  let next = Mining_counters.record_dig counters ~bailed [] in
  log ("Counters: " ^ Mining_counters.format_summary ~goal next);
  Ok next

let enter_and_play_minigame ~picture ~goal ~counters =
  log "Prompt detected; confirming dig vs NPC dialog...";
  OW.interact ();
  match
    H.wait_for ~timeout_ms:dig_enter_fade_timeout_ms
      (H.held black_hold_ms is_black)
  with
  | Some () ->
      log "Dig fade detected! Entering minigame...";
      play_entered_minigame ~picture ~goal ~counters
  | None ->
      log "No dig fade (NPC/Secret Base dialog); dismissing with B...";
      let* () =
        OW.dismiss_dialog ~log ~picture ~max_presses:max_open_dialog_presses ()
      in
      Ok counters

let handle_step_event ~picture ~goal ~counters =
  match Effects.await ~timeout_ms:step_probe_timeout_ms (fun _ -> true) with
  | Effects.Holds m ->
      let scr = US.read m in
      if scr.battle then (
        let* () = OW.run_from_battle ~log ~picture () in
        subscribe_screen ~picture;
        Ok (Mining_counters.record_battle_escaped counters))
      else if scr.dialog then (
        let* next = enter_and_play_minigame ~picture ~goal ~counters in
        subscribe_screen ~picture;
        Ok next)
      else Ok counters
  | Effects.Timeout -> Ok counters

let sweep_wall ~picture ~goal ~move_dir ~face_dir ~steps ~counters =
  subscribe_screen ~picture;
  let move_btn = OW.button_of_dir move_dir in
  let rec loop left cur =
    if left <= 0 then Ok cur
    else (
      P.press ~hold_ms:step_hold_ms ~cooldown_ms:step_cooldown_ms move_btn;
      OW.turn face_dir;
      OW.interact ();
      let* next = handle_step_event ~picture ~goal ~counters:cur in
      loop (left - 1) next)
  in
  loop steps counters

let sweep_bottom_east ~picture ~goal ~counters =
  log "Sweeping bottom-East corridor...";
  OW.run_hold Corridor_nav.North ~hold_ms:north_hug_ms;
  sweep_wall ~picture ~goal ~move_dir:Corridor_nav.East
    ~face_dir:Corridor_nav.North ~steps:sweep_steps ~counters

let sweep_east_vertical ~picture ~goal ~counters =
  log "Sweeping East vertical corridor...";
  sweep_wall ~picture ~goal ~move_dir:Corridor_nav.North
    ~face_dir:Corridor_nav.East ~steps:sweep_steps ~counters

let sweep_top_east ~picture ~goal ~counters =
  log "Sweeping top-East corridor toward North doorway...";
  OW.run_hold Corridor_nav.North ~hold_ms:north_hug_ms;
  let* counters =
    sweep_wall ~picture ~goal ~move_dir:Corridor_nav.West
      ~face_dir:Corridor_nav.North ~steps:sweep_steps ~counters
  in
  log "Returning East to NE corner...";
  OW.run_hold Corridor_nav.East ~hold_ms:east_align_ms;
  Ok counters

let sweep_north_and_top ~picture ~goal ~(sp : MS.nearby) ~counters =
  log "Sprinting East to SE corner...";
  OW.run_hold Corridor_nav.East ~hold_ms:east_align_ms;
  let* counters =
    if sp.east_vertical then sweep_east_vertical ~picture ~goal ~counters
    else (
      log "Sprinting North past empty East corridor to NE corner...";
      OW.run_hold Corridor_nav.North ~hold_ms:north_run_ms;
      Ok counters)
  in
  let* counters =
    if sp.top_east then sweep_top_east ~picture ~goal ~counters else Ok counters
  in
  log "Returning South to SE corner...";
  OW.run_hold Corridor_nav.South ~hold_ms:south_return_ms;
  Ok counters

let sweep_targeted_corridors ~picture ~goal ~(sp : MS.nearby) ~counters =
  let* counters =
    if sp.bottom_east then sweep_bottom_east ~picture ~goal ~counters
    else Ok counters
  in
  let* counters =
    if sp.east_vertical || sp.top_east then
      sweep_north_and_top ~picture ~goal ~sp ~counters
    else Ok counters
  in
  log "Returning West to South Hideaway doorway...";
  OW.run_hold Corridor_nav.North ~hold_ms:north_hug_ms;
  OW.run_hold Corridor_nav.West ~hold_ms:west_return_ms;
  Ok counters

let run_one_cycle ~picture ~goal ~total_cycles ~idx ~counters =
  log (Printf.sprintf "=== Cycle %d/%d ===" idx total_cycles);
  let* () =
    OW.bounce_doorway ~log ~picture
      ~anchor:{ Corridor_nav.enter_dir = West; exit_dir = East }
      ~hold_ms:door_bounce_hold_ms ()
  in
  let counters = Mining_counters.record_refresh counters in
  P.wait post_dig_wait_ms;
  let sp =
    match read_screen ~picture with
    | Some scr ->
        log ("Screen: " ^ US.to_string scr);
        scr.sparkles
    | None -> { MS.bottom_east = true; east_vertical = true; top_east = false }
  in
  let* counters =
    if MS.any sp then sweep_targeted_corridors ~picture ~goal ~sp ~counters
    else (
      log "No sparkles in any of the 3 ring zones; skipping sweep!";
      Ok (Mining_counters.record_skipped_corridor counters))
  in
  let counters = Mining_counters.record_cycle counters in
  log ("Counters: " ^ Mining_counters.format_summary ~goal counters);
  Ok counters

let recover_if_mid_dig ~picture ~goal ~counters =
  match read_screen ~picture with
  | Some scr when scr.mining_wall ->
      log "Started mid-dig on an active wall; finishing it first...";
      let tally = Mining_counters.to_tally counters in
      let* moves, bailed = MP.dig_wall_smart ~log ~picture ~goal ~tally () in
      log (Printf.sprintf "Recovered dig done: moves=%d bailed=%b" moves bailed);
      P.wait post_dig_wait_ms;
      let* () =
        OW.advance_dialog ~log ~picture ~max_presses:max_end_dialog_presses ()
      in
      subscribe_screen ~picture;
      ignore
        (H.wait_for ~timeout_ms:fade_timeout_ms
           (H.held clear_hold_ms is_not_black)
          : unit option);
      P.wait post_dig_wait_ms;
      OW.run_hold Corridor_nav.South ~hold_ms:south_return_ms;
      OW.run_hold Corridor_nav.North ~hold_ms:north_hug_ms;
      OW.run_hold Corridor_nav.West ~hold_ms:west_return_ms;
      Ok (Mining_counters.record_dig counters ~bailed [])
  | Some scr ->
      log ("Initial screen: " ^ US.to_string scr);
      Ok counters
  | None -> Ok counters

let run_check_bag ~picture =
  log "Mode check-bag: opening Bag -> Treasures pocket to inspect shards...";
  let* () = OW.open_menu ~log ~picture () in
  let* () = OW.menu_select ~log ~picture ~dx:0 ~dy:0 () in
  P.wait bag_open_wait_ms;
  P.press ~hold_ms:bag_nav_hold_ms ~cooldown_ms:bag_page_wait_ms Wire.Left;
  for page = 1 to bag_scroll_pages do
    log (Printf.sprintf "Treasures pocket page %d/%d..." page bag_scroll_pages);
    P.wait bag_page_wait_ms;
    for _ = 1 to bag_page_rows do
      P.press ~hold_ms:bag_nav_hold_ms ~cooldown_ms:bag_nav_cooldown_ms
        Wire.Down
    done
  done;
  log "Closing Bag back to overworld...";
  for _ = 1 to bag_exit_presses do
    P.press ~hold_ms:bag_nav_hold_ms ~cooldown_ms:bag_exit_cooldown_ms Wire.B
  done;
  Ok "treasures pocket captured"

let run_farm_loop ~picture ~goal ~total_cycles =
  let* initial =
    recover_if_mid_dig ~picture ~goal ~counters:Mining_counters.empty
  in
  let rec cycle idx counters =
    if idx > total_cycles then Ok counters
    else if Mining_goal.is_met goal (Mining_counters.to_tally counters) then (
      log "Shard/slate budget reached! Stopping early.";
      Ok counters)
    else
      let* next = run_one_cycle ~picture ~goal ~total_cycles ~idx ~counters in
      cycle (idx + 1) next
  in
  cycle 1 initial

let finish_result = function
  | Ok msg -> (true, "bdsp.underground_poc: PASS (" ^ msg ^ ")")
  | Error e -> (false, "bdsp.underground_poc: FAIL " ^ e)

let run ?(options = Run_options.none) ?state:_ () =
  let picture = native_picture in
  let mode = Option.value (Run_options.find options "mode") ~default:"farm" in
  let total_cycles =
    Option.value (Run_options.int options "cycles") ~default:default_cycles
  in
  let slates =
    Option.value (Run_options.int options "slates") ~default:default_slates
  in
  let goal = Mining_goal.Slates slates in
  if mode = "check-bag" then finish_result (run_check_bag ~picture)
  else
    finish_result
      (Result.map
         (Mining_counters.format_summary ~goal)
         (run_farm_loop ~picture ~goal ~total_cycles))
