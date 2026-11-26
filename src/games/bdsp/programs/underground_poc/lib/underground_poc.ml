module OW = Bdsp_actions.Bdsp_overworld
module MP = Bdsp_actions.Bdsp_mining_play
module B = Switch_home.Black_screen
module H = Switch_home.Held_screen
module P = Switch_home.Switch_presses
open Bdsp_underground

let ( let* ) = Result.bind

let default_state = ""
let native_picture : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. }
let step_hold_ms = 240
let step_cooldown_ms = 140
let fade_timeout_ms = 8000
let open_dlg_timeout_ms = 8000
let black_hold_ms = 80.
let clear_hold_ms = 200.
let post_open_wait_ms = 400
let post_dig_wait_ms = 1000
let step_probe_timeout_ms = 400
let max_open_dialog_presses = 6
let max_end_dialog_presses = 15
let door_bounce_hold_ms = 2500
let north_hug_ms = 450
let east_align_ms = 800
let south_return_ms = 3000
let west_return_ms = 1800
let sweep_steps = 10
let total_cycles = 3

let log msg = Printf.printf "[bdsp.underground_poc] %s\n%!" msg

let is_black m = if B.shown m then Some () else None
let is_not_black m = if not (B.shown m) then Some () else None
let is_dialog m = if Bdsp_readers.Dialog_detector.shown m then Some () else None

let subscribe_corridor ~picture =
  ignore
    (Effects.subscribe
       (B.probes ~picture
       @ Bdsp_readers.Dialog_detector.probes ~picture
       @ Bdsp_readers.Battle_detector.probes ~picture)
      : string list)

let enter_and_play_minigame ~picture ~tally =
  log "Dig prompt detected! Entering minigame...";
  OW.interact ();
  ignore
    (H.wait_for ~timeout_ms:fade_timeout_ms (H.held black_hold_ms is_black)
      : unit option);
  ignore
    (H.wait_for ~timeout_ms:fade_timeout_ms (H.held clear_hold_ms is_not_black)
      : unit option);
  ignore
    (H.wait_for ~timeout_ms:open_dlg_timeout_ms
       (H.held clear_hold_ms is_dialog)
      : unit option);
  let* () =
    OW.advance_dialog ~log ~picture ~max_presses:max_open_dialog_presses ()
  in
  P.wait post_open_wait_ms;
  let* moves, bailed =
    MP.dig_wall_smart ~log ~picture ~goal:Mining_goal.ramanas_all_slates ~tally
      ()
  in
  log (Printf.sprintf "Smart dig done: moves=%d bailed=%b" moves bailed);
  P.wait post_dig_wait_ms;
  let* () =
    OW.advance_dialog ~log ~picture ~max_presses:max_end_dialog_presses ()
  in
  ignore
    (H.wait_for ~timeout_ms:fade_timeout_ms (H.held clear_hold_ms is_not_black)
      : unit option);
  P.wait post_dig_wait_ms;
  Ok (Mining_goal.record_dig tally ~bailed [])

let handle_step_event ~picture ~tally =
  match Effects.await ~timeout_ms:step_probe_timeout_ms (fun _ -> true) with
  | Effects.Holds m when Bdsp_readers.Battle_detector.shown m ->
      let* () = OW.run_from_battle ~log ~picture () in
      Ok tally
  | Effects.Holds m when Bdsp_readers.Dialog_detector.shown m ->
      let* next_tally = enter_and_play_minigame ~picture ~tally in
      subscribe_corridor ~picture;
      Ok next_tally
  | _ -> Ok tally

let sweep_wall ~picture ~move_dir ~face_dir ~steps ~tally =
  subscribe_corridor ~picture;
  let move_btn = OW.button_of_dir move_dir in
  let rec loop left cur_tally =
    if left <= 0 then Ok cur_tally
    else (
      P.press ~hold_ms:step_hold_ms ~cooldown_ms:step_cooldown_ms move_btn;
      OW.turn face_dir;
      OW.interact ();
      let* next = handle_step_event ~picture ~tally:cur_tally in
      loop (left - 1) next)
  in
  loop steps tally

let run_one_cycle ~picture ~idx ~tally =
  log (Printf.sprintf "=== Cycle %d/%d ===" idx total_cycles);
  log "Bouncing South Hideaway doorway (West -> East, auto-centering)...";
  let* () =
    OW.bounce_doorway ~log ~picture
      ~anchor:{ Corridor_nav.enter_dir = West; exit_dir = East }
      ~hold_ms:door_bounce_hold_ms ()
  in
  P.wait post_dig_wait_ms;
  log "Hugging North wall & sweeping East toward South-East corner...";
  OW.run_hold Corridor_nav.North ~hold_ms:north_hug_ms;
  let* tally =
    sweep_wall ~picture ~move_dir:Corridor_nav.East ~face_dir:Corridor_nav.North
      ~steps:sweep_steps ~tally
  in
  log "Self-aligning East & sweeping North along East wall...";
  OW.run_hold Corridor_nav.East ~hold_ms:east_align_ms;
  let* tally =
    sweep_wall ~picture ~move_dir:Corridor_nav.North
      ~face_dir:Corridor_nav.East ~steps:sweep_steps ~tally
  in
  log "Returning South to South-East corner & West to Hideaway doorway...";
  OW.run_hold Corridor_nav.South ~hold_ms:south_return_ms;
  OW.run_hold Corridor_nav.North ~hold_ms:north_hug_ms;
  OW.run_hold Corridor_nav.West ~hold_ms:west_return_ms;
  Ok tally

let run_se_loop () =
  let picture = native_picture in
  let rec cycle idx tally =
    if idx > total_cycles then Ok tally
    else
      let* next = run_one_cycle ~picture ~idx ~tally in
      cycle (idx + 1) next
  in
  cycle 1 Mining_goal.empty_tally

let run ?state:_ () =
  match run_se_loop () with
  | Ok tally ->
      ( true,
        Printf.sprintf
          "bdsp.underground_poc: PASS (%d cycles, %d digs, %d bailed)"
          total_cycles tally.digs tally.walls_bailed )
  | Error e -> (false, "bdsp.underground_poc: FAIL " ^ e)
