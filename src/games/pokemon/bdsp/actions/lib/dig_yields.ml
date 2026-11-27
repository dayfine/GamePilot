module P = Switch.Switch_presses

type yield_cfg = {
  probe_timeout_ms : int;
  enter_timeout_ms : int;
  advance_wait_ms : int;
  max_presses : int;
  quiet_limit : int;
}

let cfg =
  {
    probe_timeout_ms = 1000;
    enter_timeout_ms = 5000;
    advance_wait_ms = 750;
    max_presses = 20;
    quiet_limit = 3;
  }

let post_dig_ui_active m =
  let scr = Bdsp_readers.Underground_screen.read m in
  scr.dialog
  || scr.fade = Screen_state.Fade.Black
  || Bdsp_readers.Dig_result_reader.on_item_spotlight m

let record_spotlight_item ~log ~in_spot acc m =
  match Bdsp_readers.Dig_result_reader.read m with
  | Some t when not in_spot ->
      log ("Uncovered item: " ^ Bdsp_readers.Dig_result_reader.treasure_name t);
      (t :: acc, true)
  | Some _ -> (acc, true)
  | None -> (acc, false)

let advance_yield_frame ~log ~quiet ~in_spot acc m =
  let scr = Bdsp_readers.Underground_screen.read m in
  let acc, saw_item = record_spotlight_item ~log ~in_spot acc m in
  let active = saw_item || scr.dialog || scr.fade <> No_fade in
  if (not active) && quiet + 1 >= cfg.quiet_limit then None
  else (
    if scr.dialog || saw_item then Overworld_actions.interact ();
    P.wait cfg.advance_wait_ms;
    Some (acc, (if active then 0 else quiet + 1), saw_item))

let poll_yield_step ~log ~quiet ~in_spot acc =
  match Effects.await ~timeout_ms:cfg.probe_timeout_ms (fun _ -> true) with
  | Effects.Timeout -> None
  | Effects.Holds m -> advance_yield_frame ~log ~quiet ~in_spot acc m

let rec collect_loop ~log ~quiet ~in_spot left acc =
  if left <= 0 then List.rev acc
  else
    match poll_yield_step ~log ~quiet ~in_spot acc with
    | None -> List.rev acc
    | Some (acc', q', spot') ->
        collect_loop ~log ~quiet:q' ~in_spot:spot' (left - 1) acc'

let collect ~log ~picture () =
  ignore
    (Effects.subscribe
       (Bdsp_readers.Underground_screen.probes ~picture
       @ Bdsp_readers.Dig_result_reader.probes ~picture)
      : string list);
  ignore
    (Effects.await ~timeout_ms:cfg.enter_timeout_ms post_dig_ui_active
      : Effects.awaited);
  collect_loop ~log ~quiet:0 ~in_spot:false cfg.max_presses []
