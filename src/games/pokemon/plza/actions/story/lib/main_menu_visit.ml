module S = Steps
module L = Look
module Failure = Engine_run.Failure

let watch_ms = 30_000
let menu_limit_ms = 120_000.
let hold_ms = 250
let poll_ms = 50
let settle_ms = 100
let x_hold_ms = 160
let x_release_ms = 240
let b_release_ms = 840
let b_presses = 60
let not_reached detail = Failure.cause "main_menu_not_reached" detail
let overworld (l : L.t) = l.party_bar && not l.main_menu

(* The overworld or the menu, held 250 ms, within 30 s. *)
let watch steps =
  let rule = S.rule ~confirm_hold_ms:hold_ms ~poll_ms ~timeout_ms:watch_ms () in
  S.wait_for steps rule (fun l -> l.main_menu || overworld l)

let on_watched steps ~log (look : L.t) =
  S.wait steps settle_ms;
  if look.main_menu then (
    log "main menu";
    true)
  else (
    log "overworld: X";
    S.press steps Wire.X ~hold_ms:x_hold_ms ~release_ms:x_release_ms;
    false)

let enter steps ~log =
  let until = S.(steps.now) () +. menu_limit_ms in
  let rec go () =
    if S.(steps.now) () >= until then
      Error (not_reached "no main menu after 120 s")
    else
      match watch steps with
      | Home_menu -> Error S.game_not_running
      | Timed_out -> Error (not_reached "no overworld or main menu in 30 s")
      | Matched { look; _ } ->
          if on_watched steps ~log look then Ok () else go ()
  in
  go ()

type out = Out | Home | Still

let out_of_menu steps =
  let l = S.(steps.read_screen) () in
  if l.home_menu then Home
  else if l.party_bar || l.dialog_box then Out
  else Still

let menu_not_closed =
  Failure.cause "menu_not_closed"
    "no party bar or talk after 60 B presses out of the menu"

let rec press_b_out steps pressed =
  match out_of_menu steps with
  | Home -> Error S.game_not_running
  | Out -> Ok ()
  | Still when pressed >= b_presses -> Error menu_not_closed
  | Still ->
      S.press steps Wire.B ~hold_ms:S.press_hold_ms ~release_ms:b_release_ms;
      press_b_out steps (pressed + 1)

let leave steps = press_b_out steps 0
