module P = Switch_home.Switch_presses

let ( let* ) = Result.bind
let press_hold_ms = 120
let prompt_wait_ms = 1500
let finish_wait_ms = 5500
let max_dismiss_presses = 6

let save_game ~log ~picture () =
  log "Saving game (X -> R -> A)...";
  let* () = Bdsp_overworld.open_menu ~log ~picture () in
  P.press ~hold_ms:press_hold_ms ~cooldown_ms:prompt_wait_ms Wire.R;
  P.press ~hold_ms:press_hold_ms ~cooldown_ms:finish_wait_ms Wire.A;
  ignore
    (Bdsp_overworld.dismiss_dialog ~log ~picture
       ~max_presses:max_dismiss_presses ()
      : (unit, string) result);
  log "Save complete.";
  Ok ()
