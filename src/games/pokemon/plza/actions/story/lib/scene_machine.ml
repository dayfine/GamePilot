module S = Steps
module L = Look

type config = {
  end_on_black_fade : bool;
  stop_at_choice : bool;
  stop_at_battle : bool;
  button : Wire.button;
  start_window_ms : int option;
}

let default =
  {
    end_on_black_fade = false;
    stop_at_choice = false;
    stop_at_battle = false;
    button = A;
    start_window_ms = None;
  }

let control_hold_ms = 1000.0
let control_instead_hold_ms = 5000.0
let text_a_again_ms = 2000.0
let poll_ms = 250
let press_hold_ms = S.press_hold_ms
let press_release_ms = S.press_release_ms
let timeout_ms = 360_000
let short_timeout_ms = 120_000
let battle_timeout_ms = 90_000

type screen =
  | Battle
  | Locked_on
  | Fade
  | Black_fade_end
  | Choice_end
  | Choice
  | Text
  | Lock_on
  | Card
  | Ended_in_control
  | Never_started
  | Awaiting_scene
  | Control
  | Control_showing
  | Other

let name = function
  | Battle -> "battle"
  | Locked_on -> "locked_on"
  | Fade -> "fade"
  | Black_fade_end -> "black_fade"
  | Choice_end -> "choice"
  | Choice -> "choice_top_row"
  | Text -> "text"
  | Lock_on -> "lock_on"
  | Card -> "card"
  | Ended_in_control -> "ended_in_control"
  | Never_started -> "never_started"
  | Awaiting_scene -> "awaiting_scene"
  | Control -> "control"
  | Control_showing -> "control_showing"
  | Other -> "other"

let terminal = function
  | Battle | Locked_on | Black_fade_end | Choice_end | Ended_in_control
  | Never_started | Control ->
      true
  | _ -> false

(* The last A on text with stop_at_choice and the button A: when, and whether
   its page showed the advance arrow. *)
type text_a = { at : float; arrow : bool }

(* What earlier reads showed; each hold is when its sign started. *)
type timeline = {
  mutable start : float option;
  mutable scene_seen : bool;
  mutable overworld_seen : bool;
  mutable control_since : float option;
  mutable control_instead_since : float option;
  mutable black_fades : int;
  mutable text_a : text_a option;
  lock : Lock_on.state;
}

let held since ~hold_ms (l : L.t) =
  match since with Some t -> l.at_ms -. t >= hold_ms | None -> false

(* Not when stopping at a choice or a battle: the talk shows control between
   lines. *)
let party_bar_is_control config =
  not (config.stop_at_choice || config.stop_at_battle)

let ends_machine config (l : L.t) =
  if party_bar_is_control config then L.control_shows l
  else l.controls_hint && not l.dialog_box

let expected_end config =
  (if config.stop_at_battle then "the battle HUD, " else "")
  ^ (if config.stop_at_choice then "the choice box, " else "")
  ^
  if party_bar_is_control config then
    "the controls hint, the party bar or the A prompt"
  else "the controls hint"

let classify_held tl (l : L.t) =
  if held tl.control_since ~hold_ms:control_hold_ms l then Control
  else if held tl.control_instead_since ~hold_ms:control_instead_hold_ms l then
    Ended_in_control
  else Control_showing

(* With a start window, control before any scene waits for one, up to the
   window. *)
let classify_control config tl (l : L.t) =
  match config.start_window_ms with
  | Some window when not tl.scene_seen ->
      if held tl.start ~hold_ms:(float_of_int window) l then Never_started
      else Awaiting_scene
  | _ -> classify_held tl l

let classify_rest config tl (l : L.t) =
  if L.card_shows l then Card
  else if L.control_shows l then classify_control config tl l
  else Other

let classify config tl (l : L.t) =
  if config.stop_at_battle && l.battle then Battle
  else if tl.lock.locked_on then Locked_on
  else if L.fade_shows l then
    if config.end_on_black_fade && l.fade_black then Black_fade_end else Fade
  else if l.choice_box then if config.stop_at_choice then Choice_end else Choice
  else if L.text_shows l then Text
  else if config.stop_at_battle && Lock_on.due tl.lock l then Lock_on
  else classify_rest config tl l

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

(* stop_at_choice with A: a new page (its arrow came or went), or the last
   A's page 2 s on. *)
let text_a_due tl (l : L.t) =
  match tl.text_a with
  | None -> true
  | Some a -> a.arrow <> l.advance_arrow || l.at_ms -. a.at >= text_a_again_ms

let text_button config tl (l : L.t) =
  if config.stop_at_choice then
    if config.button <> Wire.A then Some config.button
    else if text_a_due tl l then Some Wire.A
    else None
  else if L.hud_shows l || tl.overworld_seen then Some Wire.B
  else Some config.button

(* None after a battle's fade (A there is a move) or with stop_at_choice (an
   A in flight as the choice opens takes its top row). *)
let other_button config tl =
  if config.stop_at_choice || (config.stop_at_battle && tl.lock.after_fade) then
    None
  else if tl.overworld_seen then Some Wire.B
  else Some config.button

let button steps config tl screen (l : L.t) =
  match screen with
  | Choice -> Some (choice_button steps l)
  | Text -> text_button config tl l
  | Card -> Some Wire.A
  | Other -> other_button config tl
  | _ -> None

let since_while on since (l : L.t) =
  if on then Some (Option.value since ~default:l.at_ms) else None

let record_text_a config tl screen (l : L.t) =
  match screen with
  | Text when config.stop_at_choice && config.button = Wire.A ->
      if text_a_due tl l then
        tl.text_a <- Some { at = l.at_ms; arrow = l.advance_arrow }
  | Text -> ()
  | _ -> tl.text_a <- None

let control_instead config (l : L.t) =
  (not (party_bar_is_control config))
  && L.control_shows l
  && not (L.scene_busy l)

let record config tl screen (l : L.t) =
  let control_instead = control_instead config l in
  Lock_on.record tl.lock ~tried:(screen = Lock_on) ~control_instead l;
  record_text_a config tl screen l;
  if l.fade_black then tl.black_fades <- tl.black_fades + 1;
  tl.overworld_seen <- tl.overworld_seen || (tl.scene_seen && L.control_shows l);
  tl.scene_seen <- tl.scene_seen || L.scene_under_way l;
  tl.control_since <- since_while (ends_machine config l) tl.control_since l;
  tl.control_instead_since <-
    since_while control_instead tl.control_instead_since l

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
         (S.seconds (l.at_ms -. start))
         readings))

let timeout_of config =
  if config.stop_at_battle then battle_timeout_ms
  else if
    config.stop_at_choice || config.button = Wire.B
    || Option.is_some config.start_window_ms
  then short_timeout_ms
  else timeout_ms

let timed_out config label =
  Scene_failure.timed_out ~label
    ~seconds:(int_of_float (S.seconds (float_of_int (timeout_of config))))
    ~expected:(expected_end config)

let failure config label screen =
  let expected = expected_end config in
  if screen = Never_started then
    Some
      (Scene_failure.never_started ~label ~expected
         ~window_ms:(Option.value config.start_window_ms ~default:0))
  else if screen = Ended_in_control then
    Some
      (Scene_failure.ended_in_control ~label ~expected
         ~hold_ms:(int_of_float control_instead_hold_ms))
  else None

let outcome steps config label screen =
  match failure config label screen with
  | Some cause -> Error cause
  | None ->
      S.(steps.log) (Printf.sprintf "[PLZA %s] done on %s." label (name screen));
      Ok ()

let new_timeline () =
  {
    start = None;
    scene_seen = false;
    overworld_seen = false;
    control_since = None;
    control_instead_since = None;
    black_fades = 0;
    text_a = None;
    lock = Lock_on.new_state ();
  }

let act steps label tl screen = function
  | _ when screen = Lock_on -> Lock_on.run tl.lock steps label
  | Some b ->
      S.press steps b ~hold_ms:press_hold_ms ~release_ms:press_release_ms
  | None -> if not (terminal screen) then S.wait steps poll_ms

let run steps label config =
  S.(steps.log)
    (Printf.sprintf "[PLZA %s] start, expecting %s." label (expected_end config));
  let tl = new_timeline () and last = ref "" in
  let limit = timeout_of config in
  let max_looks = (limit / poll_ms) + 1 in
  let rec go ~start looks =
    let look = S.(steps.read_screen) () in
    let start = Option.value start ~default:look.at_ms in
    tl.start <- Some start;
    if look.home_menu then Error S.game_not_running
    else
      let screen = classify config tl look in
      let b = button steps config tl screen look in
      record config tl screen look;
      log_look steps label ~start last screen tl look;
      act steps label tl screen b;
      if terminal screen then outcome steps config label screen
      else if look.at_ms -. start >= float_of_int limit || looks >= max_looks
      then Error (timed_out config label)
      else go ~start:(Some start) (looks + 1)
  in
  go ~start:None 1
