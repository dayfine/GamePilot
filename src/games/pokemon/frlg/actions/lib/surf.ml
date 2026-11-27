module M = Menu_input

(* After YES, "<mon> used SURF!" and its A, then stepping onto water:
   once the dialog closes, YES was taken. *)
let surf_started m = not (Frlg_readers.Dialog.dialog_up m)

let surf ~log =
  log "Surf onto water.";
  M.press Wire.A;
  M.answer_yes ~code:"surf_no_prompt" ~taken:surf_started
    "the water's Surf question";
  M.settle_back ~label:"surf" ~log
