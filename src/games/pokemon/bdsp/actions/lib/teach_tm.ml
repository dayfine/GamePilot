module P = Switch.Switch_presses

let ( let* ) = Result.bind

type request = {
  tm_row : int;
  party_slot : int;
  replace_move_slot : int option;
}

type game_steps = {
  open_tm_pocket : unit -> (unit, string) result;
  select_tm : int -> unit;
  choose_party_slot : int -> (unit, string) result;
  replace_move : int option -> (unit, string) result;
  close_to_overworld : unit -> unit;
  log : string -> unit;
}

type slot_bounds = {
  min_party : int;
  max_party : int;
  min_move : int;
  max_move : int;
}

type tm_timing = {
  press_hold_ms : int;
  confirm_wait_ms : int;
  nav_hold_ms : int;
  nav_cooldown_ms : int;
  pocket_wait_ms : int;
}

let bounds : slot_bounds =
  { min_party = 1; max_party = 6; min_move = 1; max_move = 4 }

let timing : tm_timing =
  {
    press_hold_ms = 120;
    confirm_wait_ms = 900;
    nav_hold_ms = 80;
    nav_cooldown_ms = 160;
    pocket_wait_ms = 350;
  }

let validate_move_slot = function
  | Some s when s < bounds.min_move || s > bounds.max_move ->
      Error
        (Printf.sprintf "teach_tm: replace_move_slot %d out of range %d..%d" s
           bounds.min_move bounds.max_move)
  | _ -> Ok ()

let validate_request (req : request) =
  if req.tm_row < 0 then
    Error (Printf.sprintf "teach_tm: negative tm_row %d" req.tm_row)
  else if req.party_slot < bounds.min_party || req.party_slot > bounds.max_party
  then
    Error
      (Printf.sprintf "teach_tm: party_slot %d out of range %d..%d"
         req.party_slot bounds.min_party bounds.max_party)
  else validate_move_slot req.replace_move_slot

let execute_teach steps (req : request) =
  steps.log
    (Printf.sprintf "Teaching TM row %d to party slot %d..." req.tm_row
       req.party_slot);
  steps.select_tm req.tm_row;
  let* () = steps.choose_party_slot req.party_slot in
  steps.replace_move req.replace_move_slot

let run steps req =
  let* () = validate_request req in
  let* () = steps.open_tm_pocket () in
  match execute_teach steps req with
  | Ok () ->
      steps.close_to_overworld ();
      Ok ()
  | Error _ as err ->
      steps.close_to_overworld ();
      err

let repeat_press btn n =
  for _ = 1 to max 0 n do
    P.press ~hold_ms:timing.nav_hold_ms ~cooldown_ms:timing.nav_cooldown_ms btn
  done

let step_pocket ~from ~to_ =
  match Bdsp_readers.Bag_pocket_reader.pocket_steps ~from ~to_ with
  | `Stay -> ()
  | `Right n ->
      repeat_press Wire.Right n;
      P.wait timing.pocket_wait_ms
  | `Left n ->
      repeat_press Wire.Left n;
      P.wait timing.pocket_wait_ms

let press_confirm n =
  for _ = 1 to n do
    P.press ~hold_ms:timing.press_hold_ms ~cooldown_ms:timing.confirm_wait_ms
      Wire.A
  done

let live_replace_move ~log ~picture = function
  | None -> Overworld_actions.advance_dialog ~log ~picture ()
  | Some move_slot ->
      press_confirm 4;
      repeat_press Wire.Down (move_slot - 1);
      press_confirm 2;
      Overworld_actions.advance_dialog ~log ~picture ()

let live_game_steps ~start_pocket ~log ~picture =
  let open_tm_pocket () =
    log "Opening Bag -> TMs pocket...";
    let* () = Overworld_actions.open_menu ~log ~picture () in
    let* () = Overworld_actions.menu_select ~log ~picture ~dx:0 ~dy:0 () in
    P.wait Overworld_timing.dlg.bag_open_wait_ms;
    step_pocket ~from:start_pocket ~to_:Tms;
    Ok ()
  in
  let select_tm tm_row =
    repeat_press Wire.Down tm_row;
    press_confirm 2
  in
  let choose_party_slot slot =
    repeat_press Wire.Down (slot - 1);
    press_confirm 1;
    Ok ()
  in
  let replace_move = live_replace_move ~log ~picture in
  let close_to_overworld () =
    log "Closing Bag back to overworld...";
    for _ = 1 to Overworld_timing.bag.exit_presses do
      P.press ~hold_ms:Overworld_timing.bag.nav_hold_ms
        ~cooldown_ms:Overworld_timing.bag.exit_cooldown_ms Wire.B
    done
  in
  {
    open_tm_pocket;
    select_tm;
    choose_party_slot;
    replace_move;
    close_to_overworld;
    log;
  }
