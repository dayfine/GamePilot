open Frlg_readers
module M = Menu_input

let nurse_front : Story.Pose.grid =
  { map = ""; tiles = [ { x = 7; y = 4 } ]; facing = Some North }

let center_map town = town ^ "_PokemonCenter_1F"
let dialog_press_ms = 340
let dialog_presses = 20
let mash_a_ms = 8000
let mash_b_ms = 5000

(* The fork's mash: a tap each [tap_hold_ms + tap_release_ms] for [ms]. *)
let mash button ms = M.taps button (ms / (M.tap_hold_ms + M.tap_release_ms))

let heal_at_nurse ~log () =
  log "Center: heal at the nurse.";
  M.press_until ~max_presses:dialog_presses ~code:"heal_no_dialog"
    "the nurse's text" Wire.A ~cooldown_ms:dialog_press_ms Dialog.dialog_up;
  mash Wire.A mash_a_ms;
  mash Wire.B mash_b_ms;
  M.settle_back ~label:"heal" ~log

let save_row = 4
let overwrite_question_ms = 3000

let save ~log () =
  log "Save.";
  Menu_cursor.open_start_menu_row save_row;
  M.answer_yes ~code:"save_no_question" "the save question";
  ignore
    (M.await_screen ~code:"save_no_question" "the save question closing"
       (fun m -> not (Dialog.selection_dialog m)));
  ignore (M.answer_yes_if_asked ~timeout_ms:overwrite_question_ms);
  M.settle_back ~label:"save" ~log
