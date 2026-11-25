module S = Story_steps
module L = Story_look
module Failure = Engine_run.Failure

let poll_ms = 250
let menu_open_wait_ms = 2000
let limit_ms = 30000
let held_looks = 2
let card_close_wait_ms = 1500
let card_pages_max = 3

(* From the main menu to the options' text speed, set to Fast; each with its
   release. *)
let presses =
  [
    (Wire.L, 600);
    (Wire.Up, 300);
    (Wire.A, 1100);
    (Wire.Down, 300);
    (Wire.Right, 300);
  ]

let rec close_cards steps page =
  if page >= card_pages_max then Ok ()
  else
    let look = S.(steps.read_screen) () in
    if look.home_menu then Error S.game_not_running
    else if not look.tutorial_card then Ok ()
    else (
      S.(steps.log) "[PLZA set_text_speed_fast] tutorial card: A";
      S.press steps Wire.A ~hold_ms:160 ~release_ms:240;
      S.wait steps card_close_wait_ms;
      close_cards steps (page + 1))

let back_to_overworld steps =
  match
    S.poll_until steps
      (S.rule ~confirm_looks:held_looks ~poll_ms ~timeout_ms:limit_ms ())
      L.overworld_free (fun look ->
        if L.overworld_free look then S.wait steps poll_ms
        else S.press steps Wire.B ~hold_ms:160 ~release_ms:840)
  with
  | Matched { elapsed_ms; _ } ->
      S.(steps.log)
        (Printf.sprintf
           "[PLZA set_text_speed_fast] text speed set, back on the overworld \
            at %.1fs"
           (elapsed_ms /. 1000.0));
      Ok ()
  | Home_menu -> Error S.game_not_running
  | Timed_out ->
      Error
        (Failure.cause "text_speed_timeout"
           (Printf.sprintf
              "not back on the overworld in %d ms of B after the text speed \
               rows"
              limit_ms))

let run steps =
  S.press steps Wire.X ~hold_ms:160 ~release_ms:240;
  S.wait steps menu_open_wait_ms;
  Result.bind (close_cards steps 0) (fun () ->
      List.iter
        (fun (b, release_ms) -> S.press steps b ~hold_ms:100 ~release_ms)
        presses;
      back_to_overworld steps)
