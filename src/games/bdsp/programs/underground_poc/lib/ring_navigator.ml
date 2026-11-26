module OW = Bdsp_actions.Bdsp_overworld
module US = Bdsp_readers.Underground_screen
module MS = Bdsp_readers.Minimap_sparkles
module P = Switch_home.Switch_presses
open Bdsp_underground

let ( let* ) = Result.bind
let step_hold_ms = 320
let step_cooldown_ms = 110
let sprint_burst_ms = 260
let max_sprint_bursts = 12
let bucket_probe_steps = 3
let step_probe_timeout_ms = 350
let north_hug_ms = 450
let east_align_ms = 2000
let north_run_ms = 2800
let south_return_ms = 3000
let west_return_ms = 2600

let subscribe_screen ~picture =
  ignore (Effects.subscribe (US.probes ~picture) : string list)

let reached_bucket corridor target_bucket scr =
  match scr.US.sparkles.player with
  | Some p -> p.corridor = corridor && p.bucket >= target_bucket
  | None -> false

let sprint_to_bucket ~picture ~corridor ~dir ~target_bucket =
  subscribe_screen ~picture;
  let rec loop left =
    if left <= 0 then ()
    else
      match Effects.await ~timeout_ms:step_probe_timeout_ms (fun _ -> true) with
      | Effects.Holds m when reached_bucket corridor target_bucket (US.read m)
        ->
          ()
      | _ ->
          OW.run_hold dir ~hold_ms:sprint_burst_ms;
          loop (left - 1)
  in
  loop max_sprint_bursts

let handle_step ~picture ~on_prompt ~on_battle cur =
  match Effects.await ~timeout_ms:step_probe_timeout_ms (fun _ -> true) with
  | Effects.Holds m ->
      let scr = US.read m in
      if scr.battle then (
        let* next = on_battle cur in
        subscribe_screen ~picture;
        Ok (next, false))
      else if scr.dialog then (
        let* next, dug = on_prompt cur in
        subscribe_screen ~picture;
        Ok (next, dug))
      else Ok (cur, false)
  | Effects.Timeout -> Ok (cur, false)

let probe_bucket_walls ~picture ~on_prompt ~on_battle ~move_dir ~face_dir cur =
  subscribe_screen ~picture;
  let move_btn = OW.button_of_dir move_dir in
  let rec loop left acc =
    if left <= 0 then Ok acc
    else (
      OW.turn face_dir;
      OW.interact ();
      let* next, dug = handle_step ~picture ~on_prompt ~on_battle acc in
      if dug then Ok next
      else (
        P.press ~hold_ms:step_hold_ms ~cooldown_ms:step_cooldown_ms move_btn;
        loop (left - 1) next))
  in
  loop bucket_probe_steps cur

let targets_in corridor targets =
  List.filter (fun (t : MS.target) -> t.corridor = corridor) targets

let visit_list ~log ~picture ~on_prompt ~on_battle ~corridor ~move_dir ~face_dir
    ts init =
  List.fold_left
    (fun acc (t : MS.target) ->
      let* cur = acc in
      log (Printf.sprintf "Sprinting to sparkle bucket %d..." t.bucket);
      sprint_to_bucket ~picture ~corridor ~dir:move_dir ~target_bucket:t.bucket;
      probe_bucket_walls ~picture ~on_prompt ~on_battle ~move_dir ~face_dir cur)
    (Ok init) ts

let visit_bottom_east ~log ~picture ~on_prompt ~on_battle targets cur =
  let ts = targets_in MS.Bottom_east targets in
  if ts = [] then Ok cur
  else (
    log "Targeting bottom-East sparkles...";
    OW.run_hold Corridor_nav.North ~hold_ms:north_hug_ms;
    visit_list ~log ~picture ~on_prompt ~on_battle ~corridor:MS.Bottom_east
      ~move_dir:Corridor_nav.East ~face_dir:Corridor_nav.North ts cur)

let visit_east_leg ~log ~picture ~on_prompt ~on_battle ev cur =
  if ev <> [] then (
    log "Targeting East-vertical sparkles...";
    visit_list ~log ~picture ~on_prompt ~on_battle ~corridor:MS.East_vertical
      ~move_dir:Corridor_nav.North ~face_dir:Corridor_nav.East ev cur)
  else (
    log "Sprinting North past empty East corridor to NE corner...";
    OW.run_hold Corridor_nav.North ~hold_ms:north_run_ms;
    Ok cur)

let visit_top_leg ~log ~picture ~on_prompt ~on_battle te cur =
  if te = [] then Ok cur
  else (
    log "Targeting top-East sparkles...";
    OW.run_hold Corridor_nav.North ~hold_ms:north_hug_ms;
    let* next =
      visit_list ~log ~picture ~on_prompt ~on_battle ~corridor:MS.Top_east
        ~move_dir:Corridor_nav.West ~face_dir:Corridor_nav.North te cur
    in
    OW.run_hold Corridor_nav.East ~hold_ms:east_align_ms;
    Ok next)

let visit_east_and_top ~log ~picture ~on_prompt ~on_battle targets cur =
  let ev = targets_in MS.East_vertical targets in
  let te = targets_in MS.Top_east targets in
  if ev = [] && te = [] then Ok cur
  else (
    log "Sprinting East to SE corner...";
    OW.run_hold Corridor_nav.East ~hold_ms:east_align_ms;
    let* cur = visit_east_leg ~log ~picture ~on_prompt ~on_battle ev cur in
    let* cur = visit_top_leg ~log ~picture ~on_prompt ~on_battle te cur in
    log "Returning South to SE corner...";
    OW.run_hold Corridor_nav.South ~hold_ms:south_return_ms;
    Ok cur)

let visit_targets ~log ~picture ~(sparkles : MS.nearby) ~on_prompt ~on_battle
    cur =
  let* cur =
    visit_bottom_east ~log ~picture ~on_prompt ~on_battle sparkles.targets cur
  in
  let* cur =
    visit_east_and_top ~log ~picture ~on_prompt ~on_battle sparkles.targets cur
  in
  log "Returning West to South Hideaway doorway...";
  OW.run_hold Corridor_nav.North ~hold_ms:north_hug_ms;
  OW.run_hold Corridor_nav.West ~hold_ms:west_return_ms;
  Ok cur
