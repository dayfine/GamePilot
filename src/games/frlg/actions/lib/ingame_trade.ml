open Frlg_readers
module M = Menu_input

let trade_presses = 45
let trade_press_ms = 1000
let party_timeout_ms = 15000

let trade ~log ~slot =
  log (Printf.sprintf "Trade: offer slot %d." slot);
  M.press Wire.A;
  M.answer_yes ~code:"trade_no_question" "the trader's offer";
  let m =
    M.await_screen ~timeout_ms:party_timeout_ms ~code:"trade_no_party"
      "the party to trade from" Party_menu.party_menu
  in
  Party_actions.choose_slot m slot;
  M.press_until ~max_presses:trade_presses ~code:"trade_not_done"
    "the trader's text after the trade" Wire.A ~cooldown_ms:trade_press_ms
    (fun m -> Dialog.dialog_up m && not (Party_menu.party_menu m));
  M.settle_back ~label:"trade" ~log
