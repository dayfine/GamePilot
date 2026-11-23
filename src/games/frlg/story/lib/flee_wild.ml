open Frlg_readers
module M = Frlg_actions.Menu_input

let menu_timeout_ms = 20000
let text_press_ms = 500

let press buttons =
  let hold = M.hold ~hold_ms:M.button_hold_ms ~cooldown_ms:M.tap_release_ms in
  ignore (Effects.submit (List.map hold buttons))

let b_until code what reader =
  M.press_until
    ~max_presses:(menu_timeout_ms / text_press_ms)
    ~code what Wire.B ~cooldown_ms:text_press_ms reader

let flee_body ~log () =
  b_until "no_battle_menu" "the battle menu" Battle_screen.battle_menu;
  press Frlg_battle.Battle_cursor.run_away;
  b_until "battle_not_over" "the overworld after running" (fun m ->
      not (Battle_screen.battle_shows m));
  M.settle_back ~label:"flee" ~log

let flee ~log () =
  log "Wild battle: run.";
  match M.run (flee_body ~log) with
  | Ok () -> ()
  | Error c -> failwith ("flee: " ^ Story.Failure.cause_to_string c)
