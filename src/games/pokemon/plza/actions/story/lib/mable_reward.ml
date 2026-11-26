module S = Steps
module L = Look
module Failure = Engine_run.Failure

let ( let* ) = Result.bind
let watch_ms = 30_000
let menu_limit_ms = 120_000.
let hold_ms = 250
let poll_ms = 50
let settle_ms = 100
let x_hold_ms = 160
let x_release_ms = 240
let rows_down = 3
let down_release_ms = 400
let a_release_ms = 2840
let lines_quiet_ms = 3000
let lines_limit_ms = 60_000
let b_release_ms = 840
let b_presses = 60

let log steps fmt =
  Printf.ksprintf
    (fun s -> S.(steps.log) ("[PLZA] claim_mable_research_reward: " ^ s))
    fmt

let not_reached detail = Failure.cause "main_menu_not_reached" detail
let overworld (l : L.t) = l.party_bar && not l.main_menu

(* The overworld or the menu, held 250 ms, within 30 s. *)
let watch steps =
  let rule = S.rule ~confirm_hold_ms:hold_ms ~poll_ms ~timeout_ms:watch_ms () in
  S.wait_for steps rule (fun l -> l.main_menu || overworld l)

let on_watched steps (look : L.t) =
  S.wait steps settle_ms;
  if look.main_menu then (
    log steps "main menu";
    true)
  else (
    log steps "overworld: X";
    S.press steps Wire.X ~hold_ms:x_hold_ms ~release_ms:x_release_ms;
    false)

let to_main_menu steps =
  let until = S.(steps.now) () +. menu_limit_ms in
  let rec go () =
    if S.(steps.now) () >= until then
      Error (not_reached "no main menu after 120 s")
    else
      match watch steps with
      | Home_menu -> Error S.game_not_running
      | Timed_out -> Error (not_reached "no overworld or main menu in 30 s")
      | Matched { look; _ } -> if on_watched steps look then Ok () else go ()
  in
  go ()

let open_research steps =
  for _ = 1 to rows_down do
    S.press steps Wire.Down ~hold_ms:S.press_hold_ms ~release_ms:down_release_ms
  done;
  S.press steps Wire.A ~hold_ms:S.press_hold_ms ~release_ms:a_release_ms

let pass_lines steps =
  let passed =
    Press_through_lines.run steps ~quiet_ms:lines_quiet_ms
      ~limit_ms:lines_limit_ms
  in
  if passed.timed_out then
    Error
      (Failure.cause "reward_lines_endless"
         "Mable's lines did not end within 60 s")
  else if not passed.text then
    Error
      (Failure.cause "no_reward_lines"
         "no dialog after opening Mable's Research: no reward was claimed")
  else Ok ()

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

let run steps =
  let* () = to_main_menu steps in
  open_research steps;
  let* () = pass_lines steps in
  press_b_out steps 0
