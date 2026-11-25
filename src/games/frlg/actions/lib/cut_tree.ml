module M = Menu_input

let turn_hold_ms = 40

(* After YES, "<mon> used CUT!" and its A, then the cut on the overworld:
   once a page's A went in, no text box means YES was taken. *)
let cut_started m = not (Frlg_readers.Dialog.dialog_up m)

let cut ~log direction =
  log ("Cut the tree to the " ^ Grid_geometry.Direction.name direction ^ ".");
  let turn =
    M.hold ~hold_ms:turn_hold_ms ~cooldown_ms:M.tap_release_ms
      (M.dpad direction)
  in
  ignore (Effects.submit [ turn ]);
  M.press Wire.A;
  M.answer_yes ~code:"cut_no_prompt" ~taken:cut_started
    "the tree's Cut question";
  M.settle_back ~label:"cut" ~log;
  let tap = Grid_maps.Move_mechanics.frlg.walk.tap in
  ignore
    (Effects.submit
       [
         M.hold ~hold_ms:tap.hold_ms ~cooldown_ms:tap.release_ms
           (M.dpad direction);
       ])
