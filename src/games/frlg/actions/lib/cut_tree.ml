module M = Menu_input

let turn_hold_ms = 40

let cut ~log direction =
  log ("Cut the tree to the " ^ Grid_maps.Direction.name direction ^ ".");
  let turn =
    M.hold ~hold_ms:turn_hold_ms ~cooldown_ms:M.tap_release_ms
      (M.dpad direction)
  in
  ignore (Effects.submit [ turn ]);
  M.press Wire.A;
  M.answer_yes ~code:"cut_no_prompt" "the tree's Cut question";
  M.settle_back ~label:"cut" ~log;
  let tap = Grid_maps.Move_mechanics.frlg.walk.tap in
  ignore
    (Effects.submit
       [
         M.hold ~hold_ms:tap.hold_ms ~cooldown_ms:tap.release_ms
           (M.dpad direction);
       ])
