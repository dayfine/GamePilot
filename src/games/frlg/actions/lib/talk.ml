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
        (Pokemon_checkpoints.Failure.cause "nothing_picked_up"
           "no text box after A: the item is not on the faced tile")
  | Holds _ -> Scene_looks.settle Talk ~label:"pick up" ~battle_ends:false ~log

let scene ~log () =
  Scene_looks.settle Talk ~label:"scene" ~battle_ends:true ~log

(* No screen ends the question but the question itself: the YES box's default
   is taken only by our deliberate A. *)
let never_past_question (_ : Effects.measurements) = false

let answer_yes ~log () =
  ignore (Effects.submit [ press_a () ]);
  Menu_input.answer_yes ~code:"no_question" ~taken:never_past_question
    "the Yes/No question";
  Menu_input.settle_back ~label:"answer" ~log

let answer ~log ~yes () =
  if yes then Menu_input.run (answer_yes ~log) else talk ~log ()
