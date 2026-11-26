module OW = Bdsp_actions.Bdsp_overworld
module US = Bdsp_readers.Underground_screen
module B = Switch_home.Black_screen
module H = Switch_home.Held_screen
module P = Switch_home.Switch_presses

let ( let* ) = Result.bind
let btn_hold_ms = 120
let btn_wait_ms = 800
let nav_hold_ms = 110
let nav_wait_ms = 180
let map_open_wait_ms = 1500
let clamp_hold_ms = 2200
let clamp_wait_ms = 250
let oreburgh_right = 10
let oreburgh_down = 14
let fly_confirm_wait_ms = 1000
let fly_fade_timeout_ms = 15_000
let post_fly_settle_ms = 1200
let wheel_prompt_wait_ms = 1500
let kit_choice_wait_ms = 1000
let play_alone_row = 2
let kit_confirm_wait_ms = 1500
let dive_fade_timeout_ms = 25_000
let surface_confirm_wait_ms = 1200
let black_hold_ms = 80.
let clear_hold_ms = 250.
let probe_timeout_ms = 1000
let is_black m = if B.shown m then Some () else None
let is_not_black m = if not (B.shown m) then Some () else None

let wait_fade_cycle ~picture ~timeout_ms ~label =
  ignore (Effects.subscribe (B.probes ~picture) : string list);
  match H.wait_for ~timeout_ms (H.held black_hold_ms is_black) with
  | None -> Error (label ^ ": timed out waiting for fade to black")
  | Some () -> (
      match H.wait_for ~timeout_ms (H.held clear_hold_ms is_not_black) with
      | Some () -> Ok ()
      | None -> Error (label ^ ": timed out waiting for scene after fade"))

let tap_repeat btn n =
  for _ = 1 to n do
    P.press ~hold_ms:nav_hold_ms ~cooldown_ms:nav_wait_ms btn
  done

let fly_to_oreburgh ~log ~picture () =
  log "Outdoors detected: opening Town Map to fly to Oreburgh City...";
  let* () = OW.open_menu ~log ~picture () in
  P.press ~hold_ms:btn_hold_ms ~cooldown_ms:map_open_wait_ms Wire.Plus;
  P.press ~hold_ms:clamp_hold_ms ~cooldown_ms:clamp_wait_ms Wire.Up;
  P.press ~hold_ms:clamp_hold_ms ~cooldown_ms:clamp_wait_ms Wire.Left;
  tap_repeat Wire.Right oreburgh_right;
  tap_repeat Wire.Down oreburgh_down;
  P.press ~hold_ms:btn_hold_ms ~cooldown_ms:fly_confirm_wait_ms Wire.A;
  P.press ~hold_ms:btn_hold_ms ~cooldown_ms:fly_confirm_wait_ms Wire.A;
  let* () =
    wait_fade_cycle ~picture ~timeout_ms:fly_fade_timeout_ms
      ~label:"fly_to_oreburgh"
  in
  P.wait post_fly_settle_ms;
  log "Arrived in Oreburgh City.";
  Ok ()

let wait_underground_state ~picture ~wanted ~timeout_ms ~label =
  ignore (Effects.subscribe (US.probes ~picture) : string list);
  let ready m =
    let scr = US.read m in
    if scr.fade = Screen_state.Fade.No_fade && scr.in_underground = wanted then
      Some ()
    else None
  in
  match H.wait_for ~timeout_ms (H.held clear_hold_ms ready) with
  | Some () -> Ok ()
  | None -> Error (label ^ ": timed out waiting for target overworld")

let dive_via_wheel ~log ~picture () =
  log "Using Explorer Kit on + wheel (Play Alone)...";
  P.press ~hold_ms:btn_hold_ms ~cooldown_ms:btn_wait_ms Wire.Plus;
  P.press ~hold_ms:btn_hold_ms ~cooldown_ms:wheel_prompt_wait_ms Wire.Down;
  P.press ~hold_ms:btn_hold_ms ~cooldown_ms:kit_choice_wait_ms Wire.A;
  tap_repeat Wire.Down play_alone_row;
  P.press ~hold_ms:btn_hold_ms ~cooldown_ms:kit_confirm_wait_ms Wire.A;
  P.press ~hold_ms:btn_hold_ms ~cooldown_ms:kit_confirm_wait_ms Wire.A;
  let* () =
    wait_underground_state ~picture ~wanted:true
      ~timeout_ms:dive_fade_timeout_ms ~label:"dive_via_wheel"
  in
  P.wait post_fly_settle_ms;
  log "Entered Grand Underground (Central Grassland Cave hallway).";
  Ok ()

let ensure_in_underground ~log ~picture () =
  ignore (Effects.subscribe (US.probes ~picture) : string list);
  match Effects.await ~timeout_ms:probe_timeout_ms (fun _ -> true) with
  | Effects.Holds m ->
      let scr = US.read m in
      if scr.in_underground || scr.mining_wall then (
        log "Already in Grand Underground.";
        Ok ())
      else
        let* () = fly_to_oreburgh ~log ~picture () in
        dive_via_wheel ~log ~picture ()
  | Effects.Timeout -> Error "ensure_in_underground: timed out reading screen"

let home_north_ms = 2600
let home_east_ms = 6000
let home_south_ms = 11500
let home_west_ms = 6500

let home_to_south_door ~log =
  log "Homing to South Hideaway doorway (N -> E -> S -> W)...";
  OW.run_hold Bdsp_underground.Corridor_nav.North ~hold_ms:home_north_ms;
  OW.run_hold Bdsp_underground.Corridor_nav.East ~hold_ms:home_east_ms;
  OW.run_hold Bdsp_underground.Corridor_nav.South ~hold_ms:home_south_ms;
  OW.run_hold Bdsp_underground.Corridor_nav.West ~hold_ms:home_west_ms

let leave_underground ~log ~picture () =
  log "Leaving Grand Underground back to Sinnoh surface (Y -> Down -> A)...";
  P.press ~hold_ms:btn_hold_ms ~cooldown_ms:btn_wait_ms Wire.Y;
  P.press ~hold_ms:nav_hold_ms ~cooldown_ms:nav_wait_ms Wire.Down;
  P.press ~hold_ms:btn_hold_ms ~cooldown_ms:surface_confirm_wait_ms Wire.A;
  P.press ~hold_ms:btn_hold_ms ~cooldown_ms:surface_confirm_wait_ms Wire.A;
  let* () =
    wait_underground_state ~picture ~wanted:false
      ~timeout_ms:dive_fade_timeout_ms ~label:"leave_underground"
  in
  P.wait post_fly_settle_ms;
  log "Returned to Sinnoh surface.";
  Ok ()
