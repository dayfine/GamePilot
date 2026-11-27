module OW = Bdsp_actions.Overworld_actions
module Fly = Bdsp_actions.Fly
module US = Bdsp_readers.Underground_screen
module H = Screen_graph.Held_screen
module P = Switch.Switch_presses
module D = Grid_geometry.Direction

let ( let* ) = Result.bind

type transit_timings = {
  btn_hold_ms : int;
  btn_wait_ms : int;
  nav_hold_ms : int;
  nav_wait_ms : int;
  post_settle_ms : int;
  probe_timeout_ms : int;
  clear_hold_ms : float;
}

type dive_config = {
  wheel_prompt_wait_ms : int;
  kit_choice_wait_ms : int;
  play_alone_row : int;
  kit_confirm_wait_ms : int;
  fade_timeout_ms : int;
  surface_confirm_wait_ms : int;
}

type home_holds = {
  north_ms : int;
  east_ms : int;
  south_ms : int;
  west_ms : int;
}

let timing =
  {
    btn_hold_ms = 120;
    btn_wait_ms = 800;
    nav_hold_ms = 110;
    nav_wait_ms = 180;
    post_settle_ms = 1200;
    probe_timeout_ms = 1000;
    clear_hold_ms = 250.;
  }

let dive =
  {
    wheel_prompt_wait_ms = 1500;
    kit_choice_wait_ms = 1000;
    play_alone_row = 2;
    kit_confirm_wait_ms = 1500;
    fade_timeout_ms = 25_000;
    surface_confirm_wait_ms = 1200;
  }

let home = { north_ms = 2600; east_ms = 6000; south_ms = 11500; west_ms = 6500 }

let tap_repeat btn n =
  for _ = 1 to n do
    P.press ~hold_ms:timing.nav_hold_ms ~cooldown_ms:timing.nav_wait_ms btn
  done

let wait_underground_state ~picture ~wanted ~timeout_ms ~label =
  ignore (Effects.subscribe (US.probes ~picture) : string list);
  let ready m =
    let scr = US.read m in
    if scr.fade = Screen_state.Fade.No_fade && scr.in_underground = wanted then
      Some ()
    else None
  in
  match H.wait_for ~timeout_ms (H.held timing.clear_hold_ms ready) with
  | Some () -> Ok ()
  | None -> Error (label ^ ": timed out waiting for target overworld")

let dive_via_wheel ~log ~picture () =
  log "Using Explorer Kit on + wheel (Play Alone)...";
  P.press ~hold_ms:timing.btn_hold_ms ~cooldown_ms:timing.btn_wait_ms Wire.Plus;
  P.press ~hold_ms:timing.btn_hold_ms ~cooldown_ms:dive.wheel_prompt_wait_ms
    Wire.Down;
  P.press ~hold_ms:timing.btn_hold_ms ~cooldown_ms:dive.kit_choice_wait_ms
    Wire.A;
  tap_repeat Wire.Down dive.play_alone_row;
  P.press ~hold_ms:timing.btn_hold_ms ~cooldown_ms:dive.kit_confirm_wait_ms
    Wire.A;
  P.press ~hold_ms:timing.btn_hold_ms ~cooldown_ms:dive.kit_confirm_wait_ms
    Wire.A;
  let* () =
    wait_underground_state ~picture ~wanted:true
      ~timeout_ms:dive.fade_timeout_ms ~label:"dive_via_wheel"
  in
  P.wait timing.post_settle_ms;
  log "Entered Grand Underground (Central Grassland Cave hallway).";
  Ok ()

let ensure_in_underground ~log ~picture () =
  ignore (Effects.subscribe (US.probes ~picture) : string list);
  match Effects.await ~timeout_ms:timing.probe_timeout_ms (fun _ -> true) with
  | Effects.Holds m ->
      let scr = US.read m in
      if scr.in_underground || scr.mining_wall then (
        log "Already in Grand Underground.";
        Ok ())
      else
        let* () = Fly.fly_to ~log ~picture Fly.oreburgh_city () in
        dive_via_wheel ~log ~picture ()
  | Effects.Timeout -> Error "ensure_in_underground: timed out reading screen"

let home_to_south_door ~log =
  log "Homing to South Hideaway doorway (N -> E -> S -> W)...";
  OW.run_hold D.North ~hold_ms:home.north_ms;
  OW.run_hold D.East ~hold_ms:home.east_ms;
  OW.run_hold D.South ~hold_ms:home.south_ms;
  OW.run_hold D.West ~hold_ms:home.west_ms

let leave_underground ~log ~picture () =
  log "Leaving Grand Underground back to Sinnoh surface (Y -> Down -> A)...";
  P.press ~hold_ms:timing.btn_hold_ms ~cooldown_ms:timing.btn_wait_ms Wire.Y;
  P.press ~hold_ms:timing.nav_hold_ms ~cooldown_ms:timing.nav_wait_ms Wire.Down;
  P.press ~hold_ms:timing.btn_hold_ms ~cooldown_ms:dive.surface_confirm_wait_ms
    Wire.A;
  P.press ~hold_ms:timing.btn_hold_ms ~cooldown_ms:dive.surface_confirm_wait_ms
    Wire.A;
  let* () =
    wait_underground_state ~picture ~wanted:false
      ~timeout_ms:dive.fade_timeout_ms ~label:"leave_underground"
  in
  P.wait timing.post_settle_ms;
  log "Returned to Sinnoh surface.";
  Ok ()

let bounce_doorway_with_rehome ~log ~picture ~hold_ms () =
  let anchor =
    { Bdsp_underground.Corridor_nav.enter_dir = D.West; exit_dir = D.East }
  in
  match OW.bounce_doorway ~log ~picture ~anchor ~hold_ms () with
  | Ok () -> Ok ()
  | Error _ ->
      log "Doorway bounce missed; re-homing to South doorway and retrying...";
      home_to_south_door ~log;
      OW.bounce_doorway ~log ~picture ~anchor ~hold_ms ()

let read_full_map_sparkles ~picture =
  let module MS = Bdsp_readers.Minimap_sparkles in
  P.press ~hold_ms:timing.btn_hold_ms ~cooldown_ms:timing.btn_wait_ms Wire.Y;
  P.press ~hold_ms:timing.btn_hold_ms ~cooldown_ms:dive.wheel_prompt_wait_ms
    Wire.A;
  ignore (Effects.subscribe (MS.full_map_probes ~picture) : string list);
  let sp =
    match Effects.await ~timeout_ms:timing.probe_timeout_ms (fun _ -> true) with
    | Effects.Holds m -> MS.read_full_map m
    | Effects.Timeout -> MS.none
  in
  P.press ~hold_ms:timing.btn_hold_ms ~cooldown_ms:timing.btn_wait_ms Wire.B;
  P.press ~hold_ms:timing.btn_hold_ms ~cooldown_ms:timing.btn_wait_ms Wire.B;
  sp
