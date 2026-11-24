open Frlg_readers
module M = Menu_input

let trade_presses = 45
let trade_press_ms = 1000
let party_timeout_ms = 15000
let text_hold_ms = 300

(* [reader] on every frame for [ms] (frame times): the trade scene's fade into
   its blue box reads as the white box for a frame or two (mg-02 testing, run 2
   of frlg/mg-02-paced). *)
let held_for ms reader =
  let since = ref None in
  fun (m : Effects.measurements) ->
    if reader m then (
      let start = Option.value !since ~default:m.t_ms in
      since := Some start;
      m.t_ms -. start >= float ms)
    else (
      since := None;
      false)

let trade ~log ~slot =
  log (Printf.sprintf "Trade: offer slot %d." slot);
  M.press Wire.A;
  M.answer_yes ~code:"trade_no_question" "the trader's offer";
  ignore
    (M.await_screen ~timeout_ms:party_timeout_ms ~code:"trade_no_party"
       "the party to trade from" Party_menu.party_menu);
  Party_actions.choose_slot slot;
  M.press_until ~max_presses:trade_presses ~code:"trade_not_done"
    "the trader's text after the trade" Wire.A ~cooldown_ms:trade_press_ms
    (held_for text_hold_ms (fun m ->
         Dialog.dialog_up m && not (Party_menu.party_menu m)));
  M.settle_back ~label:"trade" ~log
