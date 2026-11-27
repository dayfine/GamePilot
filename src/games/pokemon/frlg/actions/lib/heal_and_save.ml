open Frlg_readers
module M = Menu_input

let dialog_press_ms = 340
let dialog_presses = 20
let mash_a_ms = 8000
let mash_b_ms = 5000

let heal_at_nurse ~log () =
  log "Center: heal at the nurse.";
  M.press_until ~max_presses:dialog_presses ~code:"heal_no_dialog"
    "the nurse's text" Wire.A ~cooldown_ms:dialog_press_ms Dialog.dialog_up;
  M.mash Wire.A mash_a_ms;
  M.mash Wire.B mash_b_ms;
  M.settle_back ~label:"heal" ~log

let save ~log () = Game_save.save ~log ()
