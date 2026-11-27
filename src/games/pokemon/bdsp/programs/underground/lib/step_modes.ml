module OW = Bdsp_actions.Bdsp_overworld
module MP = Bdsp_actions.Bdsp_mining_play
module US = Bdsp_readers.Underground_screen
module MS = Bdsp_readers.Minimap_sparkles
module H = Switch_home.Held_screen
module P = Switch_home.Switch_presses
open Bdsp_underground

let ( let* ) = Result.bind
let door_bounce_hold_ms = 2500
let post_wait_ms = 1000
let map_press_hold_ms = 120
let map_view_wait_ms = 1500
let map_restore_wait_ms = 800
let probe_timeout_ms = 1000
let choice_wait_timeout_ms = 1400
let fade_timeout_ms = 8000
let open_dlg_timeout_ms = 8000
let black_hold_ms = 80.
let clear_hold_ms = 200.
let post_open_wait_ms = 400
let max_open_dialog_presses = 6

let subscribe_screen ~picture =
  ignore (Effects.subscribe (US.probes ~picture) : string list)

let is_black m =
  if (US.read m).fade = Screen_state.Fade.Black then Some () else None

let is_not_black m =
  if (US.read m).fade = Screen_state.Fade.Black then None else Some ()

let is_dialog m = if (US.read m).dialog then Some () else None
let is_choice_box m = if (US.read m).choice_box then Some () else None

let wait_clear ~timeout_ms f =
  ignore (H.wait_for ~timeout_ms (H.held clear_hold_ms f) : unit option)

let door_of_string = function
  | "north" -> Ring_grid.north_door
  | _ -> Ring_grid.south_door

let read_full_map_with_debug ~log ~picture =
  P.press ~hold_ms:map_press_hold_ms ~cooldown_ms:map_restore_wait_ms Wire.Y;
  P.press ~hold_ms:map_press_hold_ms ~cooldown_ms:map_view_wait_ms Wire.A;
  ignore (Effects.subscribe (MS.full_map_probes ~picture) : string list);
  let sp =
    match Effects.await ~timeout_ms:probe_timeout_ms (fun _ -> true) with
    | Effects.Holds m ->
        log ("Full map raw shares: " ^ MS.debug_full_map m);
        MS.read_full_map m
    | Effects.Timeout -> MS.none
  in
  P.press ~hold_ms:map_press_hold_ms ~cooldown_ms:map_restore_wait_ms Wire.B;
  P.press ~hold_ms:map_press_hold_ms ~cooldown_ms:map_restore_wait_ms Wire.B;
  sp

let step_refresh ~log ~picture =
  let* () =
    OW.bounce_doorway ~log ~picture
      ~anchor:{ Corridor_nav.enter_dir = West; exit_dir = East }
      ~hold_ms:door_bounce_hold_ms ()
  in
  P.wait post_wait_ms;
  Ok "refreshed doorway cleanly"

let step_read_map ~log ~picture =
  let sp = read_full_map_with_debug ~log ~picture in
  let desc = MS.to_string sp in
  log ("Detected sparkles: " ^ desc);
  Ok ("sparkles: " ^ desc)

let check_prompt_only ~log ~picture _found =
  subscribe_screen ~picture;
  match H.wait_for ~timeout_ms:choice_wait_timeout_ms is_choice_box with
  | Some () ->
      log "Reached dig Yes/No choice box (► 是 / 否)! Stopping here.";
      Ok (true, true)
  | None ->
      log "Dialog without Yes/No choice box; dismissing...";
      let* () =
        OW.dismiss_dialog ~log ~picture ~max_presses:max_open_dialog_presses ()
      in
      Ok (false, false)

let step_route_one ~log ~picture ~door =
  let sp = read_full_map_with_debug ~log ~picture in
  let desc = MS.to_string sp in
  log ("Detected sparkles: " ^ desc);
  if not (MS.any sp) then Ok "no sparkles on map"
  else
    let start_door = door_of_string door in
    let* reached =
      Ring_navigator.route_to_first_stop ~log ~picture ~start_door ~sparkles:sp
        ~on_prompt:(check_prompt_only ~log ~picture)
        ~on_battle:(fun acc ->
          let* () = OW.run_from_battle ~log ~picture () in
          Ok acc)
        false
    in
    if reached then Ok "reached dig choice box (► 是 / 否)"
    else Error "did not reach dig choice box at first stop"

let enter_from_choice ~log ~picture =
  log "On dig choice box; confirming ► 是...";
  OW.interact ();
  match
    H.wait_for ~timeout_ms:fade_timeout_ms (H.held black_hold_ms is_black)
  with
  | None -> Error "timed out waiting for fade into mining wall"
  | Some () ->
      wait_clear ~timeout_ms:fade_timeout_ms is_not_black;
      wait_clear ~timeout_ms:open_dlg_timeout_ms is_dialog;
      let* () =
        OW.advance_dialog ~log ~picture ~max_presses:max_open_dialog_presses ()
      in
      P.wait post_open_wait_ms;
      Ok ()

let try_open_prompt ~log ~picture =
  log "On overworld; pressing A once to open dig prompt...";
  OW.interact ();
  subscribe_screen ~picture;
  match H.wait_for ~timeout_ms:choice_wait_timeout_ms is_choice_box with
  | Some () -> enter_from_choice ~log ~picture
  | None -> Error "no dig choice box after pressing A"

let ensure_on_mining_wall ~log ~picture =
  subscribe_screen ~picture;
  match Effects.await ~timeout_ms:probe_timeout_ms (fun _ -> true) with
  | Effects.Timeout -> Error "timed out reading initial screen"
  | Effects.Holds m ->
      let scr = US.read m in
      if scr.mining_wall then Ok ()
      else if scr.choice_box || scr.dialog then enter_from_choice ~log ~picture
      else try_open_prompt ~log ~picture

let step_dig_one ~log ~picture ~goal =
  let* () = ensure_on_mining_wall ~log ~picture in
  let tally = Mining_counters.to_tally Mining_counters.empty in
  let* moves, bailed = MP.dig_wall_smart ~log ~picture ~goal ~tally () in
  log (Printf.sprintf "Smart dig done: moves=%d bailed=%b" moves bailed);
  P.wait post_wait_ms;
  let items = MP.collect_dig_yields ~log ~picture () in
  subscribe_screen ~picture;
  wait_clear ~timeout_ms:fade_timeout_ms is_not_black;
  let counters =
    Mining_counters.record_dig Mining_counters.empty ~bailed items
  in
  Ok (Mining_counters.format_summary ~goal counters)

let run_check_bag ~log ~picture =
  let* () = OW.inspect_treasures_bag ~log ~picture () in
  Ok "treasures pocket captured"

let run_check_map ~log =
  log "Mode check-map: opening full-sized Underground map (Y -> A)...";
  P.press ~hold_ms:map_press_hold_ms ~cooldown_ms:map_restore_wait_ms Wire.Y;
  P.press ~hold_ms:map_press_hold_ms ~cooldown_ms:map_view_wait_ms Wire.A;
  P.wait map_view_wait_ms;
  P.press ~hold_ms:map_press_hold_ms ~cooldown_ms:map_restore_wait_ms Wire.B;
  P.press ~hold_ms:map_press_hold_ms ~cooldown_ms:map_restore_wait_ms Wire.B;
  Ok "full-sized map captured"

let run ~mode ~door ~log ~picture ~goal =
  match mode with
  | "check-bag" -> Some (run_check_bag ~log ~picture)
  | "check-map" -> Some (run_check_map ~log)
  | "step-refresh" -> Some (step_refresh ~log ~picture)
  | "step-read-map" -> Some (step_read_map ~log ~picture)
  | "step-route-one" -> Some (step_route_one ~log ~picture ~door)
  | "step-dig-one" -> Some (step_dig_one ~log ~picture ~goal)
  | _ -> None
