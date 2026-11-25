module S = Steps
module L = Look
module Failure = Engine_run.Failure

let poll_ms = 250
let menu_open_wait_ms = 2000
let limit_ms = 30000
let held_looks = 2
let card_close_wait_ms = 1500
let card_pages_max = 3
let row_hold_ms = 100
let back_release_ms = 840

type row_press = { button : Wire.button; release_ms : int }

(* From the main menu to the options' text speed, set to Fast; each with its
   release. *)
let presses =
  [
    { button = Wire.L; release_ms = 600 };
    { button = Wire.Up; release_ms = 300 };
    { button = Wire.A; release_ms = 1100 };
    { button = Wire.Down; release_ms = 300 };
    { button = Wire.Right; release_ms = 300 };
  ]

let tap steps button =
  S.press steps button ~hold_ms:S.press_hold_ms ~release_ms:S.press_release_ms

let close_card steps =
  S.(steps.log) "[PLZA set_text_speed_fast] tutorial card: A";
  tap steps Wire.A;
  S.wait steps card_close_wait_ms

(* At most [card_pages_max] pages, each read before its A. *)
let rec close_cards steps page =
  if page >= card_pages_max then Ok () else on_card_page steps page

and on_card_page steps page =
  let look = S.(steps.read_screen) () in
  if look.home_menu then Error S.game_not_running
  else if not look.tutorial_card then Ok ()
  else (
    close_card steps;
    close_cards steps (page + 1))

let back_or_wait steps look =
  if L.overworld_free look then S.wait steps poll_ms
  else S.press steps Wire.B ~hold_ms:S.press_hold_ms ~release_ms:back_release_ms

let timed_out =
  Failure.cause "text_speed_timeout"
    (Printf.sprintf
       "not back on the overworld in %d ms of B after the text speed rows"
       limit_ms)

let log_back steps elapsed_ms =
  S.(steps.log)
    (Printf.sprintf
       "[PLZA set_text_speed_fast] text speed set, back on the overworld at \
        %.1fs"
       (S.seconds elapsed_ms))

let back_to_overworld steps =
  let rule =
    S.rule ~confirm_looks:held_looks ~poll_ms ~timeout_ms:limit_ms ()
  in
  match S.poll_until steps rule L.overworld_free (back_or_wait steps) with
  | Matched { elapsed_ms; _ } -> Ok (log_back steps elapsed_ms)
  | Home_menu -> Error S.game_not_running
  | Timed_out -> Error timed_out

let run steps =
  tap steps Wire.X;
  S.wait steps menu_open_wait_ms;
  Result.bind (close_cards steps 0) (fun () ->
      List.iter
        (fun p ->
          S.press steps p.button ~hold_ms:row_hold_ms ~release_ms:p.release_ms)
        presses;
      back_to_overworld steps)
