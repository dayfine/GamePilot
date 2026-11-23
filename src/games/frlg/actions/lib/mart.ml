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
  M.press Wire.A ~cooldown_ms:how_many_wait_ms;
  let right, up = Mart_plan.quantity_presses b.buy_quantity in
  M.taps Wire.Right right;
  M.taps Wire.Up up;
  M.press Wire.A;
  M.answer_yes ~code:"mart_no_confirm" ("the price of " ^ b.buy_item);
  M.press_until ~code:"mart_not_back" "the BUY list" Wire.A
    ~cooldown_ms:M.screen_timeout_ms list_back;
  log
    (Printf.sprintf "Mart: bought %d %s for $%d." b.buy_quantity b.buy_item
       b.cost);
  b.row

let run ~log stock (plan : Mart_plan.t) =
  let buys = Mart_plan.buys stock plan in
  log ("Mart (" ^ plan.map ^ "): " ^ Mart_plan.buys_to_string buys);
  M.press Wire.A ~cooldown_ms:clerk_menu_wait_ms;
  ignore
    (M.await_screen ~code:"mart_no_clerk" "the clerk's menu" Dialog.dialog_up);
  M.press Wire.A ~cooldown_ms:clerk_menu_wait_ms;
  ignore (M.await_screen ~code:"mart_no_buy_list" "the BUY list" list_back);
  ignore (List.fold_left (buy_one ~log) 0 buys);
  M.close "the BUY list" Money_box.money_box;
  M.settle_back ~label:"leave the Mart" ~log
