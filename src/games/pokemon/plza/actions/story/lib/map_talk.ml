module S = Story_steps
module L = Story_look
module Failure = Engine_run.Failure

let timeout_ms = 120_000
let control_hold_ms = 1000
let hold_ms = 160
let release_ms = 840
let poll_ms = 250

(* Before the card, text takes A; after it, B (on the map A places a pin). *)
type part = Before_card | After_card

let party_bar_free (l : L.t) = l.party_bar && not l.dialog_box

let button (l : L.t) part =
  if l.tutorial_card then Wire.A
  else if L.text_shows l && part = Before_card then Wire.A
  else Wire.B

let press steps part (l : L.t) =
  S.press steps (button l !part) ~hold_ms ~release_ms;
  if l.tutorial_card then part := After_card

let act steps part (l : L.t) =
  if party_bar_free l then S.wait steps poll_ms else press steps part l

let timed_out =
  Failure.cause "map_talk_timeout"
    (Printf.sprintf
       "no party bar held %d ms within %d ms of A on the talk and the card, B \
        on the map"
       control_hold_ms timeout_ms)

let run steps =
  let part = ref Before_card in
  let rule = S.rule ~confirm_hold_ms:control_hold_ms ~poll_ms ~timeout_ms () in
  match S.poll_until steps rule party_bar_free (act steps part) with
  | Matched _ ->
      S.(steps.log)
        "[PLZA] talk_through_map_screen: the party bar held: back in the \
         overworld";
      Ok ()
  | Home_menu -> Error S.game_not_running
  | Timed_out -> Error timed_out
