open Bdsp_underground
open Overworld_timing
module B = Switch.Black_screen
module H = Screen_graph.Held_screen
module P = Switch.Switch_presses

let ( let* ) = Result.bind
let mech = Grid_maps.Move_mechanics.bdsp

let button_of_dir = function
  | Grid_geometry.Direction.North -> Wire.Up
  | South -> Wire.Down
  | East -> Wire.Right
  | West -> Wire.Left

let turn dir =
  P.press ~hold_ms:mech.turn_tap_ms ~cooldown_ms:act.cooldown_ms
    (button_of_dir dir)

let step_tap dir count =
  let btn = button_of_dir dir in
  for _ = 1 to max 0 count do
    P.press ~hold_ms:mech.walk.tap.hold_ms ~cooldown_ms:mech.walk.tap.release_ms
      btn
  done

let run_hold dir ~hold_ms =
  if hold_ms > 0 then
    let cmd =
      Wire.press ~hold_ms ~cooldown_ms:act.cooldown_ms
        [ Wire.B; button_of_dir dir ]
    in
    ignore (Effects.submit [ cmd ])

let pulse_radar () =
  P.press ~hold_ms:act.hold_ms ~cooldown_ms:act.radar_cooldown_ms Wire.R

let interact () =
  P.press ~hold_ms:act.hold_ms ~cooldown_ms:act.cooldown_ms Wire.A

let is_black m = if B.shown m then Some () else None
let is_not_black m = if not (B.shown m) then Some () else None

let wait_black_clear ~timeout_ms ~err =
  match H.wait_for ~timeout_ms (H.held door.clear_hold_ms is_not_black) with
  | Some () -> Ok ()
  | None -> Error err

let step_toward_door btn =
  let cmd = Wire.press ~hold_ms:door.step_ms ~cooldown_ms:0 [ btn ] in
  ignore (Effects.submit [ cmd ]);
  H.wait_for ~timeout_ms:door.step_ms (H.held door.black_hold_ms is_black)

let rec walk_to_door ~btn ~max_steps n =
  if n >= max_steps then Error "timed out waiting for doorway fade to black"
  else
    match step_toward_door btn with
    | Some () ->
        wait_black_clear ~timeout_ms:door.fade_timeout_ms
          ~err:"timed out waiting for room to appear after doorway fade"
    | None -> walk_to_door ~btn ~max_steps (n + 1)

let cross_door ~dir ~hold_ms =
  let btn = button_of_dir dir in
  let max_steps = max 1 ((hold_ms + door.step_ms - 1) / door.step_ms) in
  walk_to_door ~btn ~max_steps 0

let perp_dirs = function
  | Grid_geometry.Direction.East | West ->
      (Grid_geometry.Direction.South, Grid_geometry.Direction.North)
  | North | South -> (East, West)

let nudge_and_enter ~dir ~nudge_dir ~nudge_ms =
  P.press ~hold_ms:nudge_ms ~cooldown_ms:act.cooldown_ms
    (button_of_dir nudge_dir);
  cross_door ~dir ~hold_ms:door.retry_hold_ms

let rec try_nudges ~dir = function
  | [] -> Error "timed out waiting for doorway fade to black"
  | nudge_dir :: rest -> (
      match nudge_and_enter ~dir ~nudge_dir ~nudge_ms:door.nudge_step_ms with
      | Ok () -> Ok ()
      | Error _ -> try_nudges ~dir rest)

let enter_with_nudge ~log ~dir ~hold_ms =
  match cross_door ~dir ~hold_ms with
  | Ok () -> Ok ()
  | Error _ ->
      let d1, d2 = perp_dirs dir in
      log "Doorway not centered; stepping sideways 1 tile at a time...";
      try_nudges ~dir [ d1; d2; d2 ]

let bounce_doorway ~log ~picture ~(anchor : Corridor_nav.doorway_anchor)
    ?(hold_ms = door.default_hold_ms) () =
  ignore (Effects.subscribe (B.probes ~picture) : string list);
  log "Entering Hideaway doorway...";
  let* () = enter_with_nudge ~log ~dir:anchor.enter_dir ~hold_ms in
  log "Exiting Hideaway doorway to refresh dig spots...";
  cross_door ~dir:anchor.exit_dir ~hold_ms

let menu_is_open m =
  if Bdsp_readers.Menu_detector.shown m then Some () else None

let menu_is_closed m =
  if not (Bdsp_readers.Menu_detector.shown m) then Some () else None

let open_menu ~log ~picture () =
  ignore
    (Effects.subscribe (Bdsp_readers.Menu_detector.probes ~picture ())
      : string list);
  P.press ~hold_ms:menu.press_hold_ms ~cooldown_ms:menu.press_cooldown_ms Wire.X;
  match
    H.wait_for ~timeout_ms:menu.wait_timeout_ms
      (H.held door.clear_hold_ms menu_is_open)
  with
  | None -> Error "Menu not detected after 10 seconds."
  | Some () ->
      log "Detected menu.";
      P.wait menu.post_wait_ms;
      Ok ()

let close_menu ~log ~picture () =
  ignore
    (Effects.subscribe (Bdsp_readers.Menu_detector.probes ~picture ())
      : string list);
  P.press ~hold_ms:menu.press_hold_ms ~cooldown_ms:menu.press_cooldown_ms Wire.B;
  match
    H.wait_for ~timeout_ms:menu.wait_timeout_ms
      (H.held door.clear_hold_ms menu_is_closed)
  with
  | None -> Error "Menu did not close after 10 seconds."
  | Some () ->
      log "Menu closed.";
      Ok ()

let dialog_is_closed m =
  if not (Bdsp_readers.Dialog_detector.shown m) then Some () else None

let press_dialog_once ~btn ~log =
  log ("Dialog detected; pressing " ^ Wire.string_of_button btn ^ "...");
  P.press ~hold_ms:menu.press_hold_ms ~cooldown_ms:dlg.press_cooldown_ms btn;
  H.wait_for ~timeout_ms:dlg.press_cooldown_ms
    (H.held door.clear_hold_ms dialog_is_closed)

let rec clear_dialog_loop ~btn ~label ~log ~max_presses n =
  match Effects.await ~timeout_ms:dlg.frame_timeout_ms (fun _ -> true) with
  | Effects.Timeout -> Error (label ^ ": no frame received")
  | Effects.Holds m when not (Bdsp_readers.Dialog_detector.shown m) ->
      log "Dialog clear.";
      Ok ()
  | Effects.Holds _ when n >= max_presses ->
      Error (label ^ ": dialog still showing")
  | Effects.Holds _ -> (
      match press_dialog_once ~btn ~log with
      | Some () ->
          log "Dialog cleared.";
          Ok ()
      | None -> clear_dialog_loop ~btn ~label ~log ~max_presses (n + 1))

let clear_dialog_with ~btn ~label ~log ~picture ?(max_presses = dlg.max_presses)
    () =
  ignore
    (Effects.subscribe (Bdsp_readers.Dialog_detector.probes ~picture)
      : string list);
  clear_dialog_loop ~btn ~label ~log ~max_presses 0

let dismiss_dialog ~log ~picture ?max_presses () =
  clear_dialog_with ~btn:Wire.B ~label:"dismiss_dialog" ~log ~picture
    ?max_presses ()

let advance_dialog ~log ~picture ?max_presses () =
  clear_dialog_with ~btn:Wire.A ~label:"advance_dialog" ~log ~picture
    ?max_presses ()

let repeat_menu_dir btn n =
  for _ = 1 to abs n do
    P.press ~hold_ms:menu.nav_hold_ms ~cooldown_ms:menu.nav_cooldown_ms btn
  done

let menu_select ~log ~picture ~dx ~dy () =
  ignore
    (Effects.subscribe (Bdsp_readers.Menu_detector.probes ~picture ())
      : string list);
  if dx > 0 then repeat_menu_dir Wire.Right dx
  else if dx < 0 then repeat_menu_dir Wire.Left dx;
  if dy > 0 then repeat_menu_dir Wire.Down dy
  else if dy < 0 then repeat_menu_dir Wire.Up dy;
  P.press ~hold_ms:menu.press_hold_ms ~cooldown_ms:menu.press_cooldown_ms Wire.A;
  match
    H.wait_for ~timeout_ms:menu.wait_timeout_ms
      (H.held door.clear_hold_ms menu_is_closed)
  with
  | None -> Error "menu_select: X menu did not close after pressing A"
  | Some () ->
      log "Opened selected menu item.";
      Ok ()

let wait_dive_fade ~picture =
  ignore (Effects.subscribe (B.probes ~picture) : string list);
  match
    H.wait_for ~timeout_ms:dlg.dive_timeout_ms
      (H.held door.black_hold_ms is_black)
  with
  | None -> Error "use_explorer_kit_offline: timed out waiting for dive fade"
  | Some () ->
      wait_black_clear ~timeout_ms:dlg.dive_timeout_ms
        ~err:"use_explorer_kit_offline: timed out waiting for Grand Underground"

let use_explorer_kit_offline ~log ~picture ~explorer_kit_row () =
  let* () = open_menu ~log ~picture () in
  log "Opening Bag...";
  let* () = menu_select ~log ~picture ~dx:0 ~dy:0 () in
  P.wait dlg.bag_open_wait_ms;
  log "Selecting Explorer Kit in Key Items...";
  repeat_menu_dir Wire.Down explorer_kit_row;
  P.press ~hold_ms:menu.press_hold_ms ~cooldown_ms:dlg.kit_confirm_wait_ms
    Wire.A;
  log "Choosing Use -> Play Alone (row 2: Down 2 + A)...";
  P.press ~hold_ms:menu.press_hold_ms ~cooldown_ms:dlg.kit_confirm_wait_ms
    Wire.A;
  repeat_menu_dir Wire.Down 2;
  P.press ~hold_ms:menu.press_hold_ms ~cooldown_ms:dlg.kit_confirm_wait_ms
    Wire.A;
  log "Waiting for Grand Underground fade...";
  let* () = wait_dive_fade ~picture in
  log "Entered Grand Underground!";
  Ok ()

let battle_menu_is_open m =
  if Bdsp_readers.Battle_detector.shown m then Some () else None

let run_from_battle ~log ~picture () =
  ignore
    (Effects.subscribe
       (B.probes ~picture @ Bdsp_readers.Battle_detector.probes ~picture)
      : string list);
  log "Wild battle detected; waiting for battle menu...";
  match
    H.wait_for ~timeout_ms:dlg.battle_timeout_ms
      (H.held door.clear_hold_ms battle_menu_is_open)
  with
  | None -> Error "run_from_battle: battle menu did not appear"
  | Some () ->
      log "Battle menu open; selecting Run (Up + A)...";
      P.press ~hold_ms:menu.press_hold_ms ~cooldown_ms:menu.nav_cooldown_ms
        Wire.Up;
      P.press ~hold_ms:menu.press_hold_ms ~cooldown_ms:menu.press_cooldown_ms
        Wire.A;
      P.wait dlg.battle_run_wait_ms;
      Ok ()

let inspect_treasures_bag ~log ~picture () =
  log "Opening Bag -> Treasures pocket to inspect shards...";
  let* () = open_menu ~log ~picture () in
  let* () = menu_select ~log ~picture ~dx:0 ~dy:0 () in
  P.wait dlg.bag_open_wait_ms;
  P.press ~hold_ms:bag.nav_hold_ms ~cooldown_ms:bag.page_wait_ms Wire.Left;
  for page = 1 to bag.scroll_pages do
    log (Printf.sprintf "Treasures pocket page %d/%d..." page bag.scroll_pages);
    P.wait bag.page_wait_ms;
    for _ = 1 to bag.page_rows do
      P.press ~hold_ms:bag.nav_hold_ms ~cooldown_ms:bag.nav_cooldown_ms
        Wire.Down
    done
  done;
  log "Closing Bag back to overworld...";
  for _ = 1 to bag.exit_presses do
    P.press ~hold_ms:bag.nav_hold_ms ~cooldown_ms:bag.exit_cooldown_ms Wire.B
  done;
  Ok ()
