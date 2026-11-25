module S = Steps
module L = Look
module Failure = Engine_run.Failure

let poll_ms = 300
let platform_looks = 2
let opening_skip_after_fade_in_ms = 750.0
let cutscene_skip_hold_ms = 2000
let opening_release_ms = 400

let waited_to_outcome steps ~what ~missing (w : S.waited) =
  match w with
  | Matched { looks; _ } ->
      S.(steps.log)
        (Printf.sprintf "[PLZA] platform wait: %s after %d looks" what looks);
      Ok ()
  | Home_menu -> Error S.game_not_running
  | Timed_out -> Error (Failure.cause "platform_not_seen" missing)

let no_hint timeout_ms =
  Printf.sprintf "No controls hint on %d looks in a row within %d ms."
    platform_looks timeout_ms

let wait_for_platform steps ~timeout_ms =
  let rule = S.rule ~confirm_looks:platform_looks ~poll_ms ~timeout_ms () in
  waited_to_outcome steps ~what:"on the platform" ~missing:(no_hint timeout_ms)
    (S.wait_for steps rule L.platform_hint)

(* The opening's edges: text waiting for A, and the end of a fade. *)
type opening = {
  mutable text_waiting : bool;
  mutable fading : bool;
  mutable faded_in : float option;
}

let skip_due o (look : L.t) =
  match o.faded_in with
  | Some at ->
      look.at_ms -. at >= opening_skip_after_fade_in_ms
      && (not (L.text_shows look))
      && not look.controls_hint
  | None -> false

let on_opening_look steps o (look : L.t) =
  let waiting = L.text_waiting_for_a look in
  if waiting && not o.text_waiting then (
    S.(steps.log) "[PLZA] platform wait: text waiting for A; A";
    S.press steps Wire.A ~hold_ms:S.press_hold_ms ~release_ms:opening_release_ms);
  o.text_waiting <- waiting;
  let fade = L.fade_shows look in
  if fade then o.faded_in <- None;
  if o.fading && not fade then o.faded_in <- Some look.at_ms;
  o.fading <- fade;
  if skip_due o look then (
    S.(steps.log)
      "[PLZA] platform wait: the opening plays; Plus held to skip it";
    S.press steps Wire.Plus ~hold_ms:cutscene_skip_hold_ms
      ~release_ms:opening_release_ms;
    o.faded_in <- None);
  S.wait steps poll_ms

let opening_to_platform steps ~timeout_ms =
  let o = { text_waiting = false; fading = false; faded_in = None } in
  match
    S.poll_until steps
      (S.rule ~poll_ms ~timeout_ms ())
      (fun l -> l.autosave)
      (on_opening_look steps o)
  with
  | Matched { elapsed_ms; _ } ->
      S.(steps.log) "[PLZA] platform wait: the autosave badge is on screen";
      S.wait steps poll_ms;
      let left = max 0 (timeout_ms - int_of_float elapsed_ms) in
      wait_for_platform steps ~timeout_ms:left
  | Home_menu -> Error S.game_not_running
  | Timed_out ->
      Error
        (Failure.cause "platform_not_seen"
           (Printf.sprintf "No autosave badge seen within %d ms." timeout_ms))
