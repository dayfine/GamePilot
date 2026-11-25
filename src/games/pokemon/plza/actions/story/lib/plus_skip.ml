module S = Story_steps
module Failure = Engine_run.Failure

let poll_ms = 250
let after_fade_ms = 2500
let fade_within_ms = 5000
let fade_end_wait_ms = 15000

let skip steps =
  S.wait steps after_fade_ms;
  S.press steps Wire.Start ~hold_ms:Platform_wait.cutscene_skip_hold_ms
    ~release_ms:0;
  match
    S.wait_for steps (S.rule ~poll_ms ~timeout_ms:fade_within_ms ()) (fun l ->
        l.fade_black)
  with
  | Matched { elapsed_ms; _ } ->
      S.(steps.log)
        (Printf.sprintf "[PLZA] plus_skip: a black fade %.0f ms after the hold."
           elapsed_ms);
      Ok ()
  | Home_menu -> Error S.game_not_running
  | Timed_out ->
      let detail =
        Printf.sprintf "plus_skip: no black fade within %d ms after the hold."
          fade_within_ms
      in
      S.(steps.log) ("[PLZA] " ^ detail);
      Error (Failure.cause "cutscene_not_skipped" detail)

let run steps =
  match
    S.wait_for steps (S.rule ~poll_ms ~timeout_ms:fade_end_wait_ms ()) (fun l ->
        not l.fade_black)
  with
  | Matched _ -> skip steps
  | Home_menu -> Error S.game_not_running
  | Timed_out ->
      Error
        (Failure.cause "fade_not_ended"
           "plus_skip: the black fade did not end within 15 s")
