(* Wild Zone 1's first actions and Mable's reward on a scripted console
   (Fake_console): 03.09's run to the gate (Plza_walk.Gate_run) and catches
   (Plza_story.Catches), and 03.15's reward (Plza_story.Mable_reward). Each
   case checks one fact: the result, an input count, or one log line. *)

module L = Plza_story.Look
module C = Plza_fake_console.Fake_console

let case name input expectation = { Table_test.name; input; expectation }
let look (c : C.t) = L.empty ~at_ms:c.now
let party c = { (look c) with party_bar = true }
let text c = { (look c) with dialog_box = true; advance_arrow = true }
let since c t = c.C.now -. t

let cause_or_ok = function
  | Ok () -> "ok"
  | Error e -> Engine_run.Failure.cause_to_string e

let has_line (c : C.t) part =
  string_of_bool
    (List.exists (fun line -> Strings.Contains.substring line part) (C.lines c))

(* The inputs that held B with the stick: the gate run's runs. *)
let runs (c : C.t) =
  List.length
    (List.filter
       (fun (i : C.input) -> i.stick_ms > 0 && List.mem Wire.B i.buttons)
       c.inputs)

(* The throws: inputs with ZR. *)
let throws (c : C.t) =
  List.length
    (List.filter (fun (i : C.input) -> List.mem Wire.ZR i.buttons) c.inputs)

let zl_held (c : C.t) =
  match c.inputs with i :: _ -> List.mem Wire.ZL i.buttons | [] -> false

(* A wild battle: the Run prompt, and the move symbols while ZL is held (none
   with [symbols] false: the target out of sight). *)
let wild_battle ?(symbols = true) c =
  {
    (party c) with
    run_prompt = true;
    moves =
      (if symbols && zl_held c then [ Some L.Effective; None; None; None ]
       else []);
  }

(* The tutorial card after the catching throw until A, then the party bar. *)
let caught c =
  let rec throw_end n = function
    | [] -> 0.
    | (i : C.input) :: rest ->
        if List.mem Wire.ZR i.buttons then
          if n = 0 then i.at_ms else throw_end (n - 1) rest
        else throw_end n rest
  in
  match C.nth_after c Wire.A ~after:(throw_end 0 c.inputs) 0 with
  | None -> { (look c) with tutorial_card = true }
  | Some _ -> party c

(* 03.09's Fletchling: the throw [catch_on] (from 1) catches it; the ones
   before break out into a wild battle. *)
let fletchling ~catch_on c =
  let n = throws c in
  if n >= catch_on then caught c else if n >= 1 then wild_battle c else party c

(* 03.09's Bunnelby, in battle from the start: the first throw catches it, or
   with [breaks_out] the first breaks out out of sight (no symbols until the
   camera sweeps: ZL with D-pad up) and the second catches it. *)
let bunnelby ?(breaks_out = false) (c : C.t) =
  let swept =
    List.exists
      (fun (i : C.input) ->
        List.mem Wire.Up i.buttons && List.mem Wire.ZL i.buttons)
      c.inputs
  in
  match throws c with
  | 0 -> wild_battle c
  | 1 when breaks_out -> wild_battle ~symbols:swept c
  | _ -> party c

(* [act] on a fresh console showing [screen]: its result and the console. *)
let acted act screen =
  let c = C.create () in
  let r = act (C.steps c screen) in
  (cause_or_ok r, c)

let result act screen () = fst (acted act screen)
let logged act screen part () = has_line (snd (acted act screen)) part
let thrown act screen () = string_of_int (throws (snd (acted act screen)))

let tutorial ~max_throws steps =
  Plza_story.Catches.catch_tutorial steps ~max_throws

let battle ~max_rounds steps =
  Plza_story.Catches.battle_then_catch steps ~max_rounds

let gate_run ?(timeout_ms = 8000) steps =
  Plza_walk.Gate_run.run (Plza_story.Steps.walk_game_steps steps) ~timeout_ms

let ran act screen () = string_of_int (runs (snd (acted act screen)))

(* The gate's A prompt once the stick was held 4.3 s. *)
let gate c =
  match C.stick_reached c 4300 with
  | None -> party c
  | Some _ -> { (party c) with interact_prompt = true }

(* A day/night change 2 s into the run: 1.5 s of nothing, then the bar; the
   gate 4.3 s into the second run. *)
let gate_after_night c =
  match C.stick_reached c 2000 with
  | None -> party c
  | Some d when since c d < 1500.0 -> look c
  | Some d -> (
      match C.stick_reached c 6300 with
      | Some g when g > d -> { (party c) with interact_prompt = true }
      | _ -> party c)

(* 03.15's reward: the party bar until X; the main menu until A; with
   [lines], Mable's text until two more A, then the Rewards page (nothing
   read) until B, then the party bar. [menu]: X opens it. *)
let mable ?(menu = true) ?(lines = true) c =
  match C.nth_after c Wire.X ~after:0. 0 with
  | None -> party c
  | Some _ when not menu -> party c
  | Some x -> (
      match C.nth_after c Wire.A ~after:x 0 with
      | None -> { (look c) with main_menu = true }
      | Some _ when not lines -> look c
      | Some a -> (
          match
            (C.nth_after c Wire.A ~after:a 1, C.nth_after c Wire.B ~after:a 0)
          with
          | None, _ -> text c
          | Some _, None -> look c
          | Some _, Some _ -> party c))

let reward = Plza_story.Mable_reward.run

let pressed act screen button () =
  let _, c = acted act screen in
  string_of_int
    (List.length
       (List.filter (fun (i : C.input) -> List.mem button i.buttons) c.inputs))

let cases_gate =
  [
    case "run_to_gate: B held to the A prompt: ok" (result gate_run gate) "ok";
    case "run_to_gate: one run" (ran gate_run gate) "18";
    case "run_to_gate: logs the gate reached"
      (logged gate_run gate "run_to_gate: the gate's A prompt: reached the gate")
      "true";
    case "run_to_gate, a day/night change: ok"
      (result gate_run gate_after_night)
      "ok";
    case "run_to_gate, a day/night change: logged"
      (logged gate_run gate_after_night
         "run_to_gate: a day/night change while running")
      "true";
    case "run_to_gate, a day/night change: runs again"
      (ran gate_run gate_after_night)
      "26";
    case "run_to_gate, no prompt: gate_not_reached" (result gate_run party)
      "gate_not_reached: no gate A prompt in 8000 ms of running";
  ]

let cases_catches =
  [
    case "catch_tutorial, caught on the first throw: ok"
      (result (tutorial ~max_throws:6) (fletchling ~catch_on:1))
      "ok";
    case "catch_tutorial, caught on the first throw: one throw"
      (thrown (tutorial ~max_throws:6) (fletchling ~catch_on:1))
      "1";
    case "catch_tutorial, caught on the first throw: logged"
      (logged (tutorial ~max_throws:6) (fletchling ~catch_on:1)
         "catch_tutorial: caught on throw 1")
      "true";
    case "catch_tutorial, a break-out: two throws"
      (thrown (tutorial ~max_throws:6) (fletchling ~catch_on:2))
      "2";
    case "catch_tutorial, a break-out: the target weakened"
      (logged (tutorial ~max_throws:6) (fletchling ~catch_on:2)
         "catch_tutorial: throw 1 broke out into a battle: 3 attacks landed")
      "true";
    case "catch_tutorial, a break-out: caught on the second"
      (logged (tutorial ~max_throws:6) (fletchling ~catch_on:2)
         "catch_tutorial: caught on throw 2")
      "true";
    case "catch_tutorial, never caught: no_catch"
      (result (tutorial ~max_throws:2) (fletchling ~catch_on:3))
      "no_catch: no tutorial card after 2 throws";
    case "catch_tutorial, nothing to catch: max_throws throws"
      (thrown (tutorial ~max_throws:6) party)
      "6";
    case "battle_then_catch: caught in round 1: ok"
      (result (battle ~max_rounds:6) bunnelby)
      "ok";
    case "battle_then_catch: one throw"
      (thrown (battle ~max_rounds:6) bunnelby)
      "1";
    case "battle_then_catch: round 1 weakens, then throws"
      (logged (battle ~max_rounds:6) bunnelby
         "battle_then_catch: round 1: 3 attacks landed, then a throw")
      "true";
    case "battle_then_catch: no lock-on twice: D-pad up for the partner"
      (logged (battle ~max_rounds:6) bunnelby
         "weaken_target: no lock-on twice: D-pad up to send the partner out")
      "true";
    case "battle_then_catch: nothing left to lock on: caught"
      (logged (battle ~max_rounds:6) bunnelby
         "battle_then_catch: nothing to lock on in round 2: caught")
      "true";
    case "battle_then_catch, a break-out out of sight: the camera sweeps"
      (logged (battle ~max_rounds:6)
         (bunnelby ~breaks_out:true)
         "nothing to lock on in round 2, still in battle: sweeping camera")
      "true";
    case "battle_then_catch, a break-out out of sight: two throws"
      (thrown (battle ~max_rounds:6) (bunnelby ~breaks_out:true))
      "2";
    case "battle_then_catch, never caught: still_a_target"
      (result (battle ~max_rounds:2) wild_battle)
      "still_a_target: a target still locks on after 2 rounds";
  ]

let cases_mable =
  [
    case "Mable's reward: ok" (result reward mable) "ok";
    case "Mable's reward: X from the overworld"
      (logged reward mable "claim_mable_research_reward: overworld: X")
      "true";
    case "Mable's reward: the main menu reached"
      (logged reward mable "claim_mable_research_reward: main menu")
      "true";
    case "Mable's reward, not in her office: no_reward_lines"
      (result reward (mable ~lines:false))
      "no_reward_lines: no dialog after opening Mable's Research: no reward \
       was claimed";
    case "Mable's reward, the menu never shows: main_menu_not_reached"
      (result reward (mable ~menu:false))
      "main_menu_not_reached: no main menu after 120 s";
    case "Mable's reward, the menu never shows: X pressed on each try"
      (pressed reward (mable ~menu:false) Wire.X)
      "139";
  ]

let () =
  Table_test.run "plza_zone_actions" (cases_gate @ cases_catches @ cases_mable)
