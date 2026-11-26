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
let fade_timeout_ms = 8000
let choice_wait_timeout_ms = 1400
let dig_enter_fade_timeout_ms = 4000
let open_dlg_timeout_ms = 8000
let black_hold_ms = 80.
let clear_hold_ms = 200.
let post_open_wait_ms = 400
let post_dig_wait_ms = 1000
let screen_probe_timeout_ms = 1000
let max_open_dialog_presses = 6
let max_end_dialog_presses = 15
let door_bounce_hold_ms = 2500
let north_hug_ms = 450
let south_return_ms = 3000
let west_return_ms = 2600

let log msg =
  let line = "[bdsp.underground_poc] " ^ msg in
  Watch_report.log print_endline line

let is_black m =
  if (US.read m).fade = Screen_state.Fade.Black then Some () else None

let is_not_black m =
  if (US.read m).fade = Screen_state.Fade.Black then None else Some ()

let is_dialog m = if (US.read m).dialog then Some () else None
let is_choice_box m = if (US.read m).choice_box then Some () else None

let wait_clear ~timeout_ms f =
  ignore (H.wait_for ~timeout_ms (H.held clear_hold_ms f) : unit option)

let subscribe_screen ~picture =
  ignore (Effects.subscribe (US.probes ~picture) : string list)

let read_screen ~picture =
  subscribe_screen ~picture;
  match Effects.await ~timeout_ms:screen_probe_timeout_ms (fun _ -> true) with
  | Effects.Holds m -> Some (US.read m)
  | Effects.Timeout -> None

let finish_active_wall ~picture ~goal ~counters =
  let tally = Mining_counters.to_tally counters in
  let* moves, bailed = MP.dig_wall_smart ~log ~picture ~goal ~tally () in
  log (Printf.sprintf "Smart dig done: moves=%d bailed=%b" moves bailed);
  P.wait post_dig_wait_ms;
  let* () =
    OW.advance_dialog ~log ~picture ~max_presses:max_end_dialog_presses ()
  in
  subscribe_screen ~picture;
  wait_clear ~timeout_ms:fade_timeout_ms is_not_black;
  P.wait post_dig_wait_ms;
  let next = Mining_counters.record_dig counters ~bailed [] in
  log ("Counters: " ^ Mining_counters.format_summary ~goal next);
  Ok next

let play_entered_minigame ~picture ~goal ~counters =
  wait_clear ~timeout_ms:fade_timeout_ms is_not_black;
  wait_clear ~timeout_ms:open_dlg_timeout_ms is_dialog;
  let* () =
    OW.advance_dialog ~log ~picture ~max_presses:max_open_dialog_presses ()
  in
  P.wait post_open_wait_ms;
  finish_active_wall ~picture ~goal ~counters

let confirm_dig_choice ~picture ~goal ~counters =
  log "Dig choice box (是/否) detected! Confirming Yes...";
  OW.interact ();
  match
    H.wait_for ~timeout_ms:dig_enter_fade_timeout_ms
      (H.held black_hold_ms is_black)
  with
  | Some () ->
      log "Dig fade detected! Entering minigame...";
      let* next = play_entered_minigame ~picture ~goal ~counters in
      Ok (next, true)
  | None ->
      log "Choice did not fade to minigame; dismissing with B...";
      let* () =
        OW.dismiss_dialog ~log ~picture ~max_presses:max_open_dialog_presses ()
      in
      Ok (counters, false)

let on_prompt ~picture ~goal counters =
  log "Dialog detected; waiting for dig Yes/No choice box...";
  match H.wait_for ~timeout_ms:choice_wait_timeout_ms is_choice_box with
  | Some () -> confirm_dig_choice ~picture ~goal ~counters
  | None ->
      log "No Yes/No choice box (NPC/Secret Base dialog); dismissing with B...";
      let* () =
        OW.dismiss_dialog ~log ~picture ~max_presses:max_open_dialog_presses ()
      in
      Ok (counters, false)

let on_battle ~picture counters =
  let* () = OW.run_from_battle ~log ~picture () in
  Ok (Mining_counters.record_battle_escaped counters)

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
    | None -> MS.none
  in
  let* counters =
    if MS.any sp then
      Ring_navigator.visit_targets ~log ~picture ~sparkles:sp
        ~on_prompt:(on_prompt ~picture ~goal) ~on_battle:(on_battle ~picture)
        counters
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
      let* next = finish_active_wall ~picture ~goal ~counters in
      OW.run_hold Corridor_nav.South ~hold_ms:south_return_ms;
      OW.run_hold Corridor_nav.North ~hold_ms:north_hug_ms;
      OW.run_hold Corridor_nav.West ~hold_ms:west_return_ms;
      Ok next
  | Some scr ->
      log ("Initial screen: " ^ US.to_string scr);
      Ok counters
  | None -> Ok counters

let run_check_bag ~picture =
  let* () = OW.inspect_treasures_bag ~log ~picture () in
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
