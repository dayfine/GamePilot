let a_hold_ms = 160

(* The text box opening after the A. *)
let a_cooldown_ms = 500

let press_a () =
  Wire.Press
    { buttons = [ Wire.A ]; hold_ms = a_hold_ms; cooldown_ms = a_cooldown_ms }

let talk ~log () =
  ignore (Effects.submit [ press_a () ]);
  Scene_looks.settle Talk ~label:"talk" ~battle_ends:true ~log

(* How long a found item's text box takes to show after the A: well under
   this on console B and mGBA. *)
let item_text_ms = 2000

let pick_up ~log () =
  ignore (Effects.submit [ press_a () ]);
  let shown =
    Effects.with_probes Frlg_readers.Dialog.probes (fun () ->
        Effects.await ~timeout_ms:item_text_ms Frlg_readers.Dialog.dialog_up)
  in
  match shown with
  | Effects.Timeout ->
      Error
        (Checkpoints.Failure.cause "nothing_picked_up"
           "no text box after A: the item is not on the faced tile")
  | Holds _ -> Scene_looks.settle Talk ~label:"pick up" ~battle_ends:false ~log

let scene ~log () =
  Scene_looks.settle Talk ~label:"scene" ~battle_ends:true ~log
