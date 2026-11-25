module S = Story_steps
module L = Story_look

let hold_ms = 2000
let turn_degrees = 90.0
let turn_ms = 150
let turn_release_ms = 100
let recenter_hold_ms = 100
let recenter_release_ms = 150

let zl_until_symbols (steps : S.game_steps) ~hold_ms =
  Option.is_some
    (steps.race
       (Wire.press ~hold_ms ~cooldown_ms:0 [ Wire.ZL ])
       Story_look.moves_shown)

let turn steps =
  match
    Plza_walk.Walk_inputs.tilt ~walk_only:true Walk ~degrees:turn_degrees
      ~duration_ms:turn_ms ~release_ms:turn_release_ms
  with
  | Ok input -> S.(steps.submit) input
  | Error _ -> ()

let result_text symbols =
  if symbols then "the move symbols showed"
  else Printf.sprintf "no move symbols in %d ms" hold_ms

let attempt steps label ~attempt ~of_ =
  let later = attempt > 1 in
  if later then (
    turn steps;
    S.press steps Wire.L ~hold_ms:recenter_hold_ms
      ~release_ms:recenter_release_ms);
  let symbols = zl_until_symbols steps ~hold_ms in
  S.(steps.log)
    (Printf.sprintf "[PLZA %s] lock-on %d/%d: %sZL held: %s." label attempt of_
       (if later then "turned 90 degrees right, L, " else "")
       (result_text symbols));
  symbols

type state = {
  mutable after_fade : bool;
  mutable quiet_since : float option;
  mutable control_since : float option;
  mutable attempts : int;
  mutable locked_on : bool;
}

let attempts = 5
let quiet_ms = 3000.0
let control_ms = 1000.0

let new_state () =
  {
    after_fade = false;
    quiet_since = None;
    control_since = None;
    attempts = 0;
    locked_on = false;
  }

let held since ~ms (l : L.t) =
  match since with Some t -> l.at_ms -. t >= ms | None -> false

let since_while on since (l : L.t) =
  if on then Some (Option.value since ~default:l.at_ms) else None

let due s (l : L.t) =
  s.after_fade && s.attempts < attempts
  && (not (L.scene_busy l))
  && (held s.quiet_since ~ms:quiet_ms l
     || (l.party_bar && held s.control_since ~ms:control_ms l))

let record s ~tried ~control_instead (l : L.t) =
  let talk = L.text_shows l || l.choice_box in
  s.attempts <- (if talk then 0 else s.attempts + if tried then 1 else 0);
  s.after_fade <- (s.after_fade && not talk) || l.fade_black;
  (* A cutscene (moving, no party bar) is not quiet. *)
  let settled = l.screen_still || l.party_bar in
  let quiet = s.after_fade && (not (L.scene_busy l)) && settled in
  s.quiet_since <- since_while quiet s.quiet_since l;
  s.control_since <- since_while control_instead s.control_since l

let run s steps label =
  if attempt steps label ~attempt:s.attempts ~of_:attempts then
    s.locked_on <- true
