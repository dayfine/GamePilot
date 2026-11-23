let a_hold_ms = 160

(* The text box opening after the A. *)
let a_cooldown_ms = 500

let press_a () =
  Wire.Press
    { buttons = [ Wire.A ]; hold_ms = a_hold_ms; cooldown_ms = a_cooldown_ms }

let talk ~log () =
  ignore (Effects.submit [ press_a () ]);
  Scene_looks.settle Talk ~label:"talk" ~battle_ends:true ~log

let scene ~log () =
  Scene_looks.settle Talk ~label:"scene" ~battle_ends:true ~log
