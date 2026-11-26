(* The scene machine (Plza_story.Scene_machine) on a scripted console
   (Fake_console), for the configs no plan on main runs yet: a stop at a
   choice, a battle's start (the HUD, or the lock-on after a battle's black
   fade), the end at a battle ahead, a start window; and its failures: a
   scene that never started, control where a choice was due, a timeout. *)

module L = Plza_story.Look
module M = Plza_story.Scene_machine
module C = Plza_fake_console.Fake_console

let case name input expectation = { Table_test.name; input; expectation }
let look (c : C.t) = L.empty ~at_ms:c.now
let text c = { (look c) with dialog_box = true; advance_arrow = true }
let hint c = { (look c) with controls_hint = true }

(* The scene run on [screen] with [config]: its outcome ("passed" or the
   failure's code) and the console. *)
let run config screen =
  let c = C.create () in
  let outcome =
    match M.run (C.steps c screen) "scene" config with
    | Ok () -> "passed"
    | Error cause -> cause.code
  in
  (outcome, c)

let outcome config screen () = fst (run config screen)

let logged config screen part () =
  let _, c = run config screen in
  string_of_bool
    (List.exists (fun line -> Substring.contains line part) (C.lines c))

(* Text for 1 s, then a two-row choice on its top row. *)
let choice_at_ms = 1000.0

let to_choice c =
  if c.C.now < choice_at_ms then text c
  else
    {
      (look c) with
      dialog_box = true;
      choice_box = true;
      choice_rows = Some (0, 2);
    }

let a_after_choice () =
  let _, c = run { M.default with stop_at_choice = true } to_choice in
  string_of_bool (C.nth_after c Wire.A ~after:choice_at_ms 0 <> None)

(* The plain scene answers the choice (A on its top row), then the hint. *)
let answered c =
  match C.nth_after c Wire.A ~after:choice_at_ms 0 with
  | None -> to_choice c
  | Some _ -> hint c

let battle c = { (look c) with battle = true }

(* A battle's black fade for 1 s, then a still screen until ZL brings up the
   move symbols. *)
let after_fade c =
  if c.C.now < 1000.0 then { (look c) with fade_black = true }
  else
    match C.last_press c Wire.ZL with
    | None -> { (look c) with screen_still = true }
    | Some _ ->
        { (look c) with screen_still = true; moves = [ Some L.Effective ] }

let zl_pressed () =
  let _, c = run { M.default with stop_at_battle = true } after_fade in
  string_of_bool (C.last_press c Wire.ZL <> None)

(* Text, then the battle HUD from 1 s on. *)
let battle_ahead c = if c.C.now < 1000.0 then text c else battle c

(* The hint for 1 s, then text, then the hint again from 3 s on. *)
let late_scene c =
  if c.C.now < 1000.0 || c.C.now >= 3000.0 then hint c else text c

let party c = { (look c) with party_bar = true }
let window = { M.default with start_window_ms = Some 2000 }
let at_choice = { M.default with stop_at_choice = true }
let at_battle = { M.default with stop_at_battle = true }
let ending_at_battle = { M.default with end_at_battle = true }

let cases =
  [
    case "stop at a choice: ends on the choice box"
      (outcome at_choice to_choice)
      "passed";
    case "stop at a choice: the choice is left unanswered" a_after_choice
      "false";
    case "a plain scene answers the choice, then ends on the hint"
      (outcome M.default answered)
      "passed";
    case "a battle's start: ends on the battle HUD" (outcome at_battle battle)
      "passed";
    case "a battle's start after its black fade: the lock-on ends it"
      (outcome at_battle after_fade)
      "passed";
    case "a battle's start after its black fade: ZL held for the lock-on"
      zl_pressed "true";
    case "a battle's start after its black fade: the try is logged"
      (logged at_battle after_fade "lock-on 1/5")
      "true";
    case "a battle ahead: the HUD ends the scene, the run goes on there"
      (outcome ending_at_battle battle_ahead)
      "battle_on_screen";
    case "a battle ahead: logged as the story battle's turn"
      (logged ending_at_battle battle_ahead "the battle HUD is up")
      "true";
    case "a start window: control waits for the scene, which then ends"
      (outcome window late_scene)
      "passed";
    case "a start window: control for the whole window, no scene"
      (outcome window hint) "scene_never_started";
    case "a stop at a choice: the party bar 5 s instead"
      (outcome at_choice party) "scene_ended_in_control";
    case "text that never ends: the scene times out" (outcome M.default text)
      "scene_timeout";
  ]

let () = Table_test.run "plza_scene_machine" cases
