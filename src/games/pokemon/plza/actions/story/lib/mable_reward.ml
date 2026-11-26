module S = Steps
module Failure = Engine_run.Failure

let ( let* ) = Result.bind
let rows_down = 3
let down_release_ms = 400
let a_release_ms = 2840
let lines_quiet_ms = 3000
let lines_limit_ms = 60_000

let log steps fmt =
  Printf.ksprintf
    (fun s -> S.(steps.log) ("[PLZA] claim_mable_research_reward: " ^ s))
    fmt

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

let run steps =
  let* () = Main_menu_visit.enter steps ~log:(log steps "%s") in
  open_research steps;
  let* () = pass_lines steps in
  Main_menu_visit.leave steps
