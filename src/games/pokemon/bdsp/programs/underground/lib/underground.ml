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
let door_bounce_hold_ms = 2500
let map_press_hold_ms = 120
let map_view_wait_ms = 1500
let map_restore_wait_ms = 800

let step_refresh, step_read_map, step_route, step_dig, step_result =
  (0, 1, 2, 3, 4)

let cycle_step_names =
  [ "refresh_cave"; "read_map_and_plan"; "route"; "dig"; "handle_dig_result" ]

type run_ctx = {
  picture : Wire.box;
  goal : Mining_goal.goal;
  total_cycles : int;
}

let log msg = Watch_report.log print_endline ("[bdsp.underground] " ^ msg)

let publish_counters ctx counters =
  Mining_counters.watch_items ~goal:ctx.goal ~total_cycles:ctx.total_cycles
    counters
  |> List.map (fun (label, value) -> { Wire.Watch.label; value })
  |> Watch_report.counters

let opt_unit b = if b then Some () else None
let is_black m = opt_unit ((US.read m).fade = Screen_state.Fade.Black)
let is_not_black m = opt_unit ((US.read m).fade <> Screen_state.Fade.Black)
let is_dialog m = opt_unit (US.read m).dialog
let is_choice_box m = opt_unit (US.read m).choice_box

let wait_clear ~timeout_ms f =
  ignore (H.wait_for ~timeout_ms (H.held clear_hold_ms f) : unit option)

let subscribe_screen ~picture =
  ignore (Effects.subscribe (US.probes ~picture) : string list)

let read_screen ~picture =
  subscribe_screen ~picture;
  match Effects.await ~timeout_ms:screen_probe_timeout_ms (fun _ -> true) with
  | Effects.Holds m -> Some (US.read m)
  | Effects.Timeout -> None

let handle_dig_result ~report ctx ~bailed ~counters =
  Watch_report.set report step_result Wire.Watch.Current "reading dig yields";
  P.wait post_dig_wait_ms;
  let items = MP.collect_dig_yields ~log ~picture:ctx.picture () in
  subscribe_screen ~picture:ctx.picture;
  wait_clear ~timeout_ms:fade_timeout_ms is_not_black;
  P.wait post_dig_wait_ms;
  let next = Mining_counters.record_dig counters ~bailed items in
  let summary = Mining_counters.format_summary ~goal:ctx.goal next in
  log ("Counters: " ^ summary);
  publish_counters ctx next;
  Watch_report.set report step_result Wire.Watch.Done summary;
  Ok next

let read_announced_items ~picture =
  ignore
    (Effects.subscribe (Bdsp_readers.Mining_announce_reader.probes ~picture)
      : string list);
  match Effects.await ~timeout_ms:screen_probe_timeout_ms (fun _ -> true) with
  | Effects.Holds m ->
      let n = Bdsp_readers.Mining_announce_reader.read m in
      Option.iter
        (fun k -> log (Printf.sprintf "Opening dialog announced %d item(s)" k))
        n;
      n
  | Effects.Timeout -> None

let run_dig_step ?announced_items ~report ctx ~counters () =
  Watch_report.set report step_dig Wire.Watch.Current "mining wall";
  let tally = Mining_counters.to_tally counters in
  let* moves, bailed =
    MP.dig_wall_smart ?announced_items ~log ~picture:ctx.picture ~goal:ctx.goal
      ~tally ()
  in
  let detail = Printf.sprintf "moves=%d bailed=%b" moves bailed in
  log ("Smart dig done: " ^ detail);
  Watch_report.set report step_dig Wire.Watch.Done detail;
  handle_dig_result ~report ctx ~bailed ~counters

let play_entered_minigame ~report ctx ~counters =
  wait_clear ~timeout_ms:fade_timeout_ms is_not_black;
  wait_clear ~timeout_ms:open_dlg_timeout_ms is_dialog;
  let announced_items = read_announced_items ~picture:ctx.picture in
  let* () =
    OW.advance_dialog ~log ~picture:ctx.picture
      ~max_presses:max_open_dialog_presses ()
  in
  P.wait post_open_wait_ms;
  run_dig_step ?announced_items ~report ctx ~counters ()

let dismiss_and_skip ctx counters msg =
  log msg;
  let* () =
    OW.dismiss_dialog ~log ~picture:ctx.picture
      ~max_presses:max_open_dialog_presses ()
  in
  Ok (counters, false)

let confirm_dig_choice ~report ctx ~counters =
  log "Dig choice box (是/否) detected! Confirming Yes...";
  OW.interact ();
  match
    H.wait_for ~timeout_ms:dig_enter_fade_timeout_ms
      (H.held black_hold_ms is_black)
  with
  | Some () ->
      log "Dig fade detected! Entering minigame...";
      let* next = play_entered_minigame ~report ctx ~counters in
      Ok (next, true)
  | None ->
      dismiss_and_skip ctx counters
        "Choice did not fade to minigame; dismissing with B..."

let on_prompt ~report ctx counters =
  log "Dialog detected; waiting for dig Yes/No choice box...";
  match H.wait_for ~timeout_ms:choice_wait_timeout_ms is_choice_box with
  | Some () -> confirm_dig_choice ~report ctx ~counters
  | None ->
      dismiss_and_skip ctx counters
        "No Yes/No choice box (NPC/Secret Base dialog); dismissing with B..."

let on_battle ctx counters =
  let* () = OW.run_from_battle ~log ~picture:ctx.picture () in
  let next = Mining_counters.record_battle_escaped counters in
  publish_counters ctx next;
  Ok next

let read_full_map_sparkles ~picture =
  P.press ~hold_ms:map_press_hold_ms ~cooldown_ms:map_restore_wait_ms Wire.Y;
  P.press ~hold_ms:map_press_hold_ms ~cooldown_ms:map_view_wait_ms Wire.A;
  ignore (Effects.subscribe (MS.full_map_probes ~picture) : string list);
  let sp =
    match Effects.await ~timeout_ms:screen_probe_timeout_ms (fun _ -> true) with
    | Effects.Holds m -> MS.read_full_map m
    | Effects.Timeout -> MS.none
  in
  P.press ~hold_ms:map_press_hold_ms ~cooldown_ms:map_restore_wait_ms Wire.B;
  P.press ~hold_ms:map_press_hold_ms ~cooldown_ms:map_restore_wait_ms Wire.B;
  sp

let home_to_south_door () = Outdoor_transit.home_to_south_door ~log

let bounce_doorway_with_rehome ~picture =
  let anchor = { Corridor_nav.enter_dir = West; exit_dir = East } in
  match
    OW.bounce_doorway ~log ~picture ~anchor ~hold_ms:door_bounce_hold_ms ()
  with
  | Ok () -> Ok ()
  | Error _ ->
      log "Doorway bounce missed; re-homing to South doorway and retrying...";
      home_to_south_door ();
      OW.bounce_doorway ~log ~picture ~anchor ~hold_ms:door_bounce_hold_ms ()

let step_refresh_cave ~report ctx counters =
  Watch_report.set report step_refresh Wire.Watch.Current
    "entering & exiting Hideaway";
  let* () = bounce_doorway_with_rehome ~picture:ctx.picture in
  P.wait post_dig_wait_ms;
  let next = Mining_counters.record_refresh counters in
  publish_counters ctx next;
  Watch_report.set report step_refresh Wire.Watch.Done
    (Printf.sprintf "refresh #%d" next.refreshes);
  Ok next

let route_targets ~report ctx ~door ~sp counters =
  if MS.any sp then (
    Watch_report.set report step_route Wire.Watch.Current
      (Printf.sprintf "%d waypoint(s)" (List.length sp.targets));
    let* next, return_door =
      Ring_navigator.visit_targets ~log ~picture:ctx.picture ~start_door:door
        ~sparkles:sp ~on_prompt:(on_prompt ~report ctx)
        ~on_battle:(on_battle ctx) counters
    in
    Watch_report.set report step_route Wire.Watch.Done "returned to doorway";
    Ok (next, return_door))
  else (
    log "No sparkles on full map; skipping route!";
    Watch_report.set report step_route Wire.Watch.Skipped "no sparkles";
    Ok (Mining_counters.record_skipped_corridor counters, door))

let run_one_cycle ctx ~idx ~door counters =
  let prev_shards = counters.Mining_counters.shard_s + counters.shard_l in
  let label = Printf.sprintf "cycle %d/%d" idx ctx.total_cycles in
  let report = Watch_report.create ~checkpoint:label cycle_step_names in
  log (Printf.sprintf "=== Cycle %d/%d ===" idx ctx.total_cycles);
  let* counters = step_refresh_cave ~report ctx counters in
  Watch_report.set report step_read_map Wire.Watch.Current "reading full map";
  let sp = read_full_map_sparkles ~picture:ctx.picture in
  let desc = MS.to_string sp in
  log ("Full map sparkles: " ^ desc);
  Watch_report.set report step_read_map Wire.Watch.Done desc;
  let* counters, next_door = route_targets ~report ctx ~door ~sp counters in
  let counters = Mining_counters.record_cycle counters in
  Auto_save.maybe_save ~log ~picture:ctx.picture ~cycle_idx:idx ~prev_shards
    counters;
  let summary = Mining_counters.format_summary ~goal:ctx.goal counters in
  log ("Counters: " ^ summary);
  publish_counters ctx counters;
  Watch_report.set report step_result Wire.Watch.Done summary;
  Ok (counters, next_door)

let rec repeat_until ~stop_when ~step state =
  if stop_when state then Ok state
  else
    let* next = step state in
    repeat_until ~stop_when ~step next

let recover_if_mid_dig ctx ~counters =
  let report = Watch_report.create ~checkpoint:"startup" cycle_step_names in
  publish_counters ctx counters;
  match read_screen ~picture:ctx.picture with
  | Some scr when scr.mining_wall ->
      log "Started mid-dig on an active wall; finishing it first...";
      let* next = run_dig_step ~report ctx ~counters () in
      home_to_south_door ();
      Ok next
  | Some scr when scr.dialog ->
      log "Started on post-dig dialog; clearing before homing...";
      ignore (MP.collect_dig_yields ~log ~picture:ctx.picture () : _ list);
      home_to_south_door ();
      Ok counters
  | Some scr ->
      log ("Initial screen: " ^ US.to_string scr);
      let* () =
        if scr.in_underground then Ok ()
        else Outdoor_transit.ensure_in_underground ~log ~picture:ctx.picture ()
      in
      home_to_south_door ();
      Ok counters
  | None -> Ok counters

let run_farm_loop ctx =
  let* initial = recover_if_mid_dig ctx ~counters:Mining_counters.empty in
  let stop_when (idx, _, counters) =
    idx > ctx.total_cycles
    || Mining_goal.is_met ctx.goal (Mining_counters.to_tally counters)
  in
  let step (idx, door, counters) =
    Result.map
      (fun (n, d) -> (idx + 1, d, n))
      (run_one_cycle ctx ~idx ~door counters)
  in
  let* _, _, final =
    repeat_until ~stop_when ~step (1, Ring_grid.south_door, initial)
  in
  Auto_save.maybe_save ~log ~picture:ctx.picture ~cycle_idx:0 ~prev_shards:0
    final;
  let* () = Outdoor_transit.leave_underground ~log ~picture:ctx.picture () in
  Ok final

let dispatch_mode ~mode ~door ctx =
  match Step_modes.run ~mode ~door ~log ~picture:ctx.picture ~goal:ctx.goal with
  | Some res -> res
  | None ->
      Result.map
        (Mining_counters.format_summary ~goal:ctx.goal)
        (run_farm_loop ctx)

let run ?(options = Run_options.none) ?state:_ () =
  let opt k d = Option.value (Run_options.find options k) ~default:d in
  let opt_i k d = Option.value (Run_options.int options k) ~default:d in
  let ctx =
    {
      picture = native_picture;
      goal = Mining_goal.Slates (opt_i "slates" default_slates);
      total_cycles = opt_i "cycles" default_cycles;
    }
  in
  match
    dispatch_mode ~mode:(opt "mode" "farm") ~door:(opt "door" "south") ctx
  with
  | Ok msg -> (true, "bdsp.underground: PASS (" ^ msg ^ ")")
  | Error e -> (false, "bdsp.underground: FAIL " ^ e)
