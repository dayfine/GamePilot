open Frlg_readers
module J = Grid_maps.Json_field
module M = Menu_input

let small = 50
let large = 500

let rec coin_batches total =
  if total >= large then large :: coin_batches (total - large)
  else if total >= small then small :: coin_batches (total - small)
  else []

let coins_of_args ~where args =
  let coins = J.int ~where "coins" args in
  if coins <= 0 || coins mod small <> 0 then
    J.fail "%scoins is %d, not a positive multiple of %d." where coins small;
  coins

let fire_red_prizes = [ "abra"; "clefairy"; "dratini"; "scyther"; "porygon" ]
let prize_slots = List.length fire_red_prizes

let prize_slot_of_args ~where args =
  let slot = J.int ~where "slot" args in
  if slot < 0 || slot >= prize_slots then
    J.fail "%sslot is %d, not a prize row (0-%d)." where slot (prize_slots - 1);
  slot

let choice_wait_ms = 1800

(* A, then A on the first page once its arrow shows: the choice box comes. *)
let to_choices ~code what =
  M.press Wire.A;
  ignore (M.await_screen ~code what Dialog.advance_arrow);
  M.press Wire.A ~cooldown_ms:choice_wait_ms

let buy_batch ~log batch =
  to_choices ~code:"coins_no_clerk" "the coins clerk's page";
  if batch = large then M.taps Wire.Down 1;
  M.press Wire.A;
  M.settle_back ~label:(Printf.sprintf "buy %d coins" batch) ~log

let buy_coins ~log coins =
  log (Printf.sprintf "Game Corner: buy %d coins." coins);
  List.iter (buy_batch ~log) (coin_batches coins)

(* The prize clerk talks in blue, so his page's arrow is blue, and the arrow
   reader knows only the red one (mg-01 run 3, 2026-11-23: "We exchange your
   COINS for prizes." done, no arrow read). As the fork: A and its wait, the
   page turned by time; here the text box is checked between. *)
let page_wait_ms = choice_wait_ms

let to_prize_choices () =
  M.press Wire.A ~cooldown_ms:page_wait_ms;
  ignore
    (M.await_screen ~code:"prize_no_clerk" "the prize clerk's page"
       Dialog.dialog_up);
  M.press Wire.A ~cooldown_ms:choice_wait_ms

(* After A on the prize, as the fork (pbf_press_button(A, 160ms, 1200ms)):
   the prize list, itself a selection box, stays up until "So, you want the
   ABRA?" has printed, and the Yes/No wait would take it for the question
   (mg-01 verification, 2026-11-23: the A meant for YES went to the list's
   last frames, the B after it answered NO, and all three runs passed with
   no Abra). *)
let prize_question_wait_ms = 1200

(* After YES the prize comes with "<player> obtained <mon>!" and the nickname
   question, which a page's A that took YES must not answer: no screen tells
   it from the clerk's own pages, so nothing counts as taken. The clerk's blue
   arrow is unread anyway, so no page gets an A here. *)
let prize_given _ = false

let redeem_prize_mon ~log slot =
  log (Printf.sprintf "Game Corner: redeem prize row %d." slot);
  to_prize_choices ();
  M.taps Wire.Down slot;
  M.press Wire.A ~cooldown_ms:prize_question_wait_ms;
  M.answer_yes ~code:"prize_no_question" ~taken:prize_given
    "the prize's question";
  M.settle_back ~label:"redeem prize" ~log
