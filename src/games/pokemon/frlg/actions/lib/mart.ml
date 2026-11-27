open Frlg_readers
module M = Menu_input

let how_many_wait_ms = 2500

(* As the fork's open_buy_list(): A, then 2 s for "May I help you?" and its
   BUY/SELL/SEE YA! box to take presses, then A on BUY and 2 s for the list
   to take the cursor. An A sent as the text box showed only finished the text
   (mg-01 run 2, 2026-11-23: the box was up, no list); a tap sent as the money
   box showed was dropped (run 3: two POKé DOLLs on row 0 for the Retro Mail on
   row 1). *)
let clerk_menu_wait_ms = 2000

(* The list back, with no text box over it. *)
let list_back m = Money_box.money_box m && not (Dialog.dialog_up m)

let buy_one ~log cursor (b : Mart_plan.buy) =
  M.moves ~from:cursor ~to_:b.row;
  (* Both A's until their screen shows: the list back from a purchase took no
     A for a moment (the quantity's UP taps then moved the cursor to POKé
     DOLL), and the quantity box dropped its A once (it stayed on x01); mGBA,
     su-01 verification, 2026-11-24. *)
  M.press_until ~max_presses:3 ~code:"mart_no_quantity" "the quantity box"
    Wire.A ~cooldown_ms:how_many_wait_ms Dialog.dialog_up;
  (* The box takes taps only once its text is out: taps sent as the text box
     showed were dropped (40 of 100 Retro Mail bought). *)
  ignore (Effects.submit [ Wire.Wait { wait_ms = how_many_wait_ms } ]);
  let right, up = Mart_plan.quantity_presses b.buy_quantity in
  M.taps Wire.Right right;
  M.taps Wire.Up up;
  Effects.with_probes Dialog.yes_no_probes (fun () ->
      M.press_until ~max_presses:3 ~code:"mart_no_confirm"
        ("the price of " ^ b.buy_item) Wire.A ~cooldown_ms:how_many_wait_ms
        (fun m -> Dialog.yes_no_cursor m <> None));
  M.answer_yes ~code:"mart_no_confirm" ~taken:list_back
    ("the price of " ^ b.buy_item);
  M.press_until ~code:"mart_not_back" "the BUY list" Wire.A
    ~cooldown_ms:M.screen_timeout_ms list_back;
  log
    (Printf.sprintf "Mart: bought %d %s for $%d." b.buy_quantity b.buy_item
       b.cost);
  b.row

let run ~log stock (plan : Mart_plan.t) =
  let buys = Mart_plan.buys stock plan in
  log ("Mart (" ^ plan.map ^ "): " ^ Mart_plan.buys_to_string buys);
  if buys <> [] then (
    M.press Wire.A ~cooldown_ms:clerk_menu_wait_ms;
    ignore
      (M.await_screen ~code:"mart_no_clerk" "the clerk's menu" Dialog.dialog_up);
    M.press Wire.A ~cooldown_ms:clerk_menu_wait_ms;
    ignore (M.await_screen ~code:"mart_no_buy_list" "the BUY list" list_back);
    ignore (List.fold_left (buy_one ~log) 0 buys);
    M.close "the BUY list" Money_box.money_box;
    M.settle_back ~label:"leave the Mart" ~log)
