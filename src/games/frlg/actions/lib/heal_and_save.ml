open Frlg_readers
module M = Menu_input

let nurse_front : Story.Pose.grid =
  { map = ""; tiles = [ { x = 7; y = 4 } ]; facing = Some North }

let center_map town = town ^ "_PokemonCenter_1F"

let heal_at_nurse ~log () =
  log "Center: heal at the nurse.";
  M.press Wire.A;
  M.answer_yes ~code:"heal_no_question" "the nurse's question";
  M.settle_back ~label:"heal" ~log

let save_row = 4
let overwrite_question_ms = 3000

let save ~log () =
  log "Save.";
  M.open_start_menu_row save_row;
  M.answer_yes ~code:"save_no_question" "the save question";
  ignore
    (M.await_screen ~code:"save_no_question" "the save question closing"
       (fun m -> not (Dialog.selection_dialog m)));
  (match
     Effects.await ~timeout_ms:overwrite_question_ms Dialog.selection_dialog
   with
  | Holds _ -> M.press Wire.A
  | Timeout -> ());
  M.settle_back ~label:"save" ~log
