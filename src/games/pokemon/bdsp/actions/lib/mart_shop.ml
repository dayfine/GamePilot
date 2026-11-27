module P = Switch.Switch_presses

let ( let* ) = Result.bind

type purchase = { row : int; quantity : int }

type game_steps = {
  open_shop : unit -> (unit, string) result;
  move_to_row : int -> unit;
  set_quantity : int -> unit;
  confirm_purchase : unit -> (unit, string) result;
  close_shop : unit -> unit;
  log : string -> unit;
}

type shop_limits = { min_qty : int; max_qty : int }

type shop_timing = {
  press_hold_ms : int;
  nav_hold_ms : int;
  nav_cooldown_ms : int;
  dialog_wait_ms : int;
  menu_wait_ms : int;
  exit_presses : int;
  exit_cooldown_ms : int;
}

let limits : shop_limits = { min_qty = 1; max_qty = 99 }

let timing : shop_timing =
  {
    press_hold_ms = 120;
    nav_hold_ms = 80;
    nav_cooldown_ms = 140;
    dialog_wait_ms = 1300;
    menu_wait_ms = 800;
    exit_presses = 4;
    exit_cooldown_ms = 900;
  }

let validate_purchase (p : purchase) =
  if p.row < 0 then Error (Printf.sprintf "mart_shop: negative row %d" p.row)
  else if p.quantity < limits.min_qty || p.quantity > limits.max_qty then
    Error
      (Printf.sprintf "mart_shop: quantity %d out of range %d..%d" p.quantity
         limits.min_qty limits.max_qty)
  else Ok ()

let rec validate_all = function
  | [] -> Ok ()
  | p :: rest ->
      let* () = validate_purchase p in
      validate_all rest

let rec buy_all steps total = function
  | [] -> Ok total
  | (p : purchase) :: rest ->
      steps.log
        (Printf.sprintf "Buying %d from shop row %d..." p.quantity p.row);
      steps.move_to_row p.row;
      steps.set_quantity p.quantity;
      let* () = steps.confirm_purchase () in
      buy_all steps (total + p.quantity) rest

let run steps purchases =
  let* () = validate_all purchases in
  match purchases with
  | [] -> Ok 0
  | _ -> (
      let* () = steps.open_shop () in
      match buy_all steps 0 purchases with
      | Ok total ->
          steps.close_shop ();
          Ok total
      | Error _ as err ->
          steps.close_shop ();
          err)

let repeat_press btn n =
  for _ = 1 to max 0 n do
    P.press ~hold_ms:timing.nav_hold_ms ~cooldown_ms:timing.nav_cooldown_ms btn
  done

let apply_qty_step = function
  | `Up n -> repeat_press Wire.Up n
  | `Down n -> repeat_press Wire.Down n
  | `Right n -> repeat_press Wire.Right n
  | `Left n -> repeat_press Wire.Left n

let live_game_steps ~log ~picture =
  let current_row = ref 0 in
  let open_shop () =
    current_row := 0;
    log "Talking to shop clerk...";
    P.press ~hold_ms:timing.press_hold_ms ~cooldown_ms:timing.dialog_wait_ms
      Wire.A;
    P.press ~hold_ms:timing.press_hold_ms ~cooldown_ms:timing.menu_wait_ms
      Wire.A;
    Ok ()
  in
  let move_to_row row =
    let delta = row - !current_row in
    if delta > 0 then repeat_press Wire.Down delta
    else if delta < 0 then repeat_press Wire.Up (-delta);
    current_row := row;
    P.press ~hold_ms:timing.press_hold_ms ~cooldown_ms:timing.menu_wait_ms
      Wire.A
  in
  let set_quantity target_qty =
    let steps =
      Bdsp_readers.Bag_pocket_reader.mart_quantity_steps ~target_qty
    in
    List.iter apply_qty_step steps
  in
  let confirm_purchase () =
    P.press ~hold_ms:timing.press_hold_ms ~cooldown_ms:timing.menu_wait_ms
      Wire.A;
    P.press ~hold_ms:timing.press_hold_ms ~cooldown_ms:timing.dialog_wait_ms
      Wire.A;
    Overworld_actions.advance_dialog ~log ~picture ()
  in
  let close_shop () =
    log "Exiting shop back to overworld...";
    for _ = 1 to timing.exit_presses do
      P.press ~hold_ms:timing.nav_hold_ms ~cooldown_ms:timing.exit_cooldown_ms
        Wire.B
    done;
    ignore
      (Overworld_actions.dismiss_dialog ~log ~picture ()
        : (unit, string) result)
  in
  { open_shop; move_to_row; set_quantity; confirm_purchase; close_shop; log }
