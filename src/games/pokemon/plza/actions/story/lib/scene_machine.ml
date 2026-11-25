module S = Story_steps
module L = Story_look
module Failure = Engine_run.Failure

type config = { end_on_black_fade : bool }

let control_hold_ms = 1000.0
let poll_ms = 250
let press_hold_ms = 160
let press_release_ms = 240
let timeout_ms = 360_000

type screen =
  | Fade
  | Black_fade_end
  | Choice
  | Text
  | Card
  | Control
  | Control_showing
  | Other

let name = function
  | Fade -> "fade"
  | Black_fade_end -> "black_fade"
  | Choice -> "choice_top_row"
  | Text -> "text"
  | Card -> "card"
  | Control -> "control"
  | Control_showing -> "control_showing"
  | Other -> "other"

let terminal = function Black_fade_end | Control -> true | _ -> false

(* What earlier reads showed. *)
type timeline = {
  mutable scene_seen : bool;
  mutable overworld_seen : bool;
  mutable control_since : float option;
  mutable black_fades : int;
}

let hud_shows (l : L.t) = l.controls_hint

let scene_under_way (l : L.t) =
  if L.text_shows l || l.choice_box || l.tutorial_card then true
  else if hud_shows l then false
  else L.fade_shows l || not l.screen_still

let classify config tl (l : L.t) =
  if L.fade_shows l then
    if config.end_on_black_fade && l.fade_black then Black_fade_end else Fade
  else if l.choice_box then Choice
  else if L.text_shows l then Text
  else if L.card_shows l then Card
  else if L.control_shows l then
    match tl.control_since with
    | Some since when l.at_ms -. since >= control_hold_ms -> Control
    | _ -> Control_showing
  else Other

let choice_button steps (l : L.t) =
  match l.choice_rows with
  | None ->
      S.(steps.log) "[PLZA scene] choice: rows not read: A";
      Wire.A
  | Some (selected, rows) when selected > 0 ->
      S.(steps.log)
        (Printf.sprintf
           "[PLZA scene] choice: %d rows, row %d highlighted: Up to row 0" rows
           selected);
      Wire.Up
  | Some (_, rows) ->
      S.(steps.log)
        (Printf.sprintf "[PLZA scene] choice: %d rows, row 0 highlighted: A"
           rows);
      Wire.A

let button steps tl screen (l : L.t) =
  match screen with
  | Choice -> Some (choice_button steps l)
  | Text -> Some (if hud_shows l || tl.overworld_seen then Wire.B else Wire.A)
  | Card -> Some Wire.A
  | Other -> Some (if tl.overworld_seen then Wire.B else Wire.A)
  | _ -> None

let record tl (l : L.t) =
  if l.fade_black then tl.black_fades <- tl.black_fades + 1;
  tl.overworld_seen <- tl.overworld_seen || (tl.scene_seen && L.control_shows l);
  tl.scene_seen <- tl.scene_seen || scene_under_way l;
  tl.control_since <-
    (if L.control_shows l then
       Some (Option.value tl.control_since ~default:l.at_ms)
     else None)

(* A line per change of class or readings. *)
let log_look steps label ~start last screen tl (l : L.t) =
  let readings =
    L.describe l
    ^
    if l.fade_black then Printf.sprintf ", black fade %d" tl.black_fades else ""
  in
  let key = name screen ^ ": " ^ readings in
  if key <> !last then (
    last := key;
    S.(steps.log_detail)
      (Printf.sprintf "[PLZA %s] %s at %.1fs: %s" label (name screen)
         ((l.at_ms -. start) /. 1000.0)
         readings))

let timed_out label =
  Failure.cause "scene_timeout"
    (Printf.sprintf
       "%s: Did not finish within %d s (expecting the controls hint, the party \
        bar or the A prompt)."
       label (timeout_ms / 1000))

let run steps label config =
  S.(steps.log)
    (Printf.sprintf
       "[PLZA %s] start, expecting the controls hint, the party bar or the A \
        prompt."
       label);
  let tl =
    {
      scene_seen = false;
      overworld_seen = false;
      control_since = None;
      black_fades = 0;
    }
  in
  let last = ref "" and max_looks = (timeout_ms / poll_ms) + 1 in
  let rec go ~start looks =
    let look = S.(steps.read_screen) () in
    let start = Option.value start ~default:look.at_ms in
    if look.home_menu then Error S.game_not_running
    else
      let screen = classify config tl look in
      let b = button steps tl screen look in
      record tl look;
      log_look steps label ~start last screen tl look;
      (match b with
      | Some b ->
          S.press steps b ~hold_ms:press_hold_ms ~release_ms:press_release_ms
      | None -> if not (terminal screen) then S.wait steps poll_ms);
      if terminal screen then (
        S.(steps.log)
          (Printf.sprintf "[PLZA %s] done on %s." label (name screen));
        Ok ())
      else if
        look.at_ms -. start >= float_of_int timeout_ms || looks >= max_looks
      then Error (timed_out label)
      else go ~start:(Some start) (looks + 1)
  in
  go ~start:None 1
