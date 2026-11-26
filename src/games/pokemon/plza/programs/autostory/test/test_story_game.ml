(* 01.01 to 03.15 run through the engine (Plza_engine.Runner) with
   Story_game's handlers on a scripted console (Fake_console): the plans
   decode, every event reaches its handler, and each handler's presses move a
   game that answers them as the console did. Also the failures: a start that
   is not Confirm Choices, a walk whose white fade never shows (lost), a
   platform never seen, a scene with no choice, a battle with no symbols or
   lost, a catch with nothing to catch, Wild Zone 1's start checks (its map
   pin and party count), an event PLZA has no handler for yet; 01.04 resumed by its skip_if
   flags, and the jump to its battle. And what the watch page is sent (Story_game.run_watched):
   the plan at each event's change and the run. *)

open Plza_engine
module L = Plza_story.Look
module C = Plza_fake_console.Fake_console

let case name input expectation = { Table_test.name; input; expectation }

let decoded source json =
  match Plan_decode.decode ~source json with Ok p -> p | Error e -> failwith e

let plan id =
  decoded (id ^ ".plan.json")
    (Yojson.Safe.from_file (Filename.concat "../plans" (id ^ ".plan.json")))

let plan_of_text text = decoded "test.plan.json" (Yojson.Safe.from_string text)

(* A reload: the console's time moves on and [reloaded] says it happened. *)
let reloaded = ref false
let look (c : C.t) = L.empty ~at_ms:c.now
let hint c = { (look c) with controls_hint = true }
let black c = { (look c) with fade_black = true }
let white c = { (look c) with fade_white = true }
let text c = { (look c) with dialog_box = true; advance_arrow = true }
let since c t = c.C.now -. t

(* 01.01: Confirm Choices on row 0 until A on row 2; a black fade; the
   opening until + held; a black fade, the autosave badge on the platform,
   then the platform. *)
let new_game ?(confirm = true) c =
  match C.nth_after c Wire.A ~after:0.0 0 with
  | None ->
      let downs =
        List.length
          (List.filter
             (fun (i : C.input) -> List.mem Wire.Down i.buttons)
             c.inputs)
      in
      if confirm then { (look c) with confirm_row = Some (min 2 downs) }
      else look c
  | Some a when since c a < 1000.0 -> black c
  | Some a -> (
      match C.nth_after c Wire.Plus ~after:a 0 with
      | None -> look c
      | Some s when since c s < 1000.0 -> black c
      | Some s when since c s < 3000.0 -> { (hint c) with autosave = true }
      | Some _ -> hint c)

(* After the arrival's white fade at [w]: 1.5 s of it, text until three A,
   the ad's black fade, until + is held, the skip's black fade, text until two
   A, a banner until one more A, then the hint. *)
let arrival c w =
  if since c w < 1500.0 then white c
  else
    match C.nth_after c Wire.A ~after:w 2 with
    | None -> text c
    | Some a3 when since c a3 < 1000.0 -> black c
    | Some a3 -> (
        match C.nth_after c Wire.Plus ~after:a3 0 with
        | None -> look c
        | Some s when since c s < 800.0 -> black c
        | Some s -> (
            match
              (C.nth_after c Wire.A ~after:s 1, C.nth_after c Wire.A ~after:s 2)
            with
            | None, _ -> text c
            | Some _, None -> look c
            | Some _, Some _ -> hint c))

(* 01.02: the platform; the menu from X until B; the walk's white fade once
   the stick was held 8 s (never when [lost]). *)
let platform ?(lost = false) ?(faded = false) c =
  match C.nth_after c Wire.X ~after:0.0 0 with
  | None when faded && not !reloaded -> look c
  | None -> hint c
  | Some x when C.nth_after c Wire.B ~after:x 0 = None -> look c
  | Some _ -> (
      match (lost, C.stick_reached c 8000) with
      | false, Some w -> arrival c w
      | _ -> hint c)

(* 01.03: free control (the hint) until the stick was held 20 s; then
   Pancham's scene, text until three B, the choice (row 1 once Down was
   pressed) until A, text until two more A, then Ryon's A prompt. [lost]: the
   walk ends by Ryon with no scene, his A prompt alone. *)
let choice c ~after =
  let down = C.nth_after c Wire.Down ~after 0 <> None in
  {
    (look c) with
    dialog_box = true;
    choice_box = true;
    choice_rows = Some ((if down then 1 else 0), 2);
  }

let prompt c = { (look c) with interact_prompt = true }

let pancham ?(lost = false) c =
  match C.stick_reached c 20_000 with
  | None -> hint c
  | Some _ when lost -> prompt c
  | Some w -> (
      match C.nth_after c Wire.B ~after:w 2 with
      | None -> text c
      | Some b3 -> (
          match C.nth_after c Wire.A ~after:b3 0 with
          | None -> choice c ~after:b3
          | Some a when C.nth_after c Wire.A ~after:a 1 = None -> text c
          | Some _ -> prompt c))

(* 01.04: Urbain's prompt (control) until the stick was held 600 ms; then
   Chikorita's prompt until A; text until one more A, the choice until A, a
   tutorial card until A, then the battle HUD with the move symbols (left
   super effective) until a move; then Andi's text until two A, then the
   alley's party bar. [no_symbols]: ZL never brings up the symbols. The lead's
   HP reads 0.89 (healthy), as console B's battles read it. *)
let healthy_hp = 0.89
let one_hp = 0.04

let battle ?(no_symbols = false) c =
  {
    (look c) with
    battle = true;
    lead_hp = Some healthy_hp;
    moves =
      (if no_symbols then []
       else [ Some L.Effective; Some L.Super_effective; None; Some L.No_effect ]);
  }

let party c = { (look c) with party_bar = true }

let andi c ~after =
  match C.nth_after c Wire.A ~after 1 with
  | None -> { (text c) with story_dialog = true }
  | Some _ -> party c

let starter ?no_symbols c =
  match C.stick_reached c 600 with
  | None -> prompt c
  | Some w -> (
      let a n = C.nth_after c Wire.A ~after:w n in
      match (a 0, a 1, a 2, a 3) with
      | None, _, _, _ -> prompt c
      | Some _, None, _, _ -> text c
      | Some _, Some _, None, _ -> choice c ~after:w
      | Some _, Some _, Some _, None -> { (look c) with tutorial_card = true }
      | Some _, Some _, Some _, Some a4 -> (
          match C.nth_after c Wire.Y ~after:a4 0 with
          | None -> battle ?no_symbols c
          | Some y -> andi c ~after:y))

(* 01.04 again after a lost battle: inside the battle (its HUD until a move),
   or Urbain's heal and Andi's challenge (text until two A, the tutorial card
   until A, then the battle). *)
let in_battle ~after c =
  match C.nth_after c Wire.Y ~after 0 with
  | None -> battle c
  | Some y -> andi c ~after:y

let rematch c =
  match C.nth_after c Wire.A ~after:0.0 2 with
  | None when C.nth_after c Wire.A ~after:0.0 1 = None ->
      { (text c) with story_dialog = true }
  | None -> { (look c) with tutorial_card = true }
  | Some a3 -> in_battle ~after:a3 c

(* 01.04 lost: the battle with the symbols until a move; then the lead
   faints (3 s of its HP bar at 1 HP of 19 under the badge, as console B's
   frames 126 and 129 read; with [no_hp], nothing read), a black fade for
   [fade_ms], then Urbain's heal line for good. *)
let starter_lost ?(no_hp = false) ~fade_ms c =
  let lost ~after =
    match C.nth_after c Wire.Y ~after 0 with
    | None -> battle c
    | Some y when since c y < 3000.0 ->
        if no_hp then look c else { (look c) with lead_hp = Some one_hp }
    | Some y when since c y < 3000.0 +. fade_ms -> black c
    | Some _ -> { (text c) with story_dialog = true }
  in
  match C.stick_reached c 600 with
  | None -> prompt c
  | Some w -> (
      match C.nth_after c Wire.A ~after:w 3 with
      | None -> starter c
      | Some a4 -> lost ~after:a4)

(* 01.04 won, the lead healthy: after the move, the HUD 1 s, then a black
   fade 2 s into Andi's line (as a won battle's cutscene shows one: 03.03,
   console B, 2026-11-25), then Andi's text until two A and the alley. *)
let starter_won_fade c =
  match C.stick_reached c 600 with
  | None -> prompt c
  | Some w -> (
      match C.nth_after c Wire.A ~after:w 3 with
      | None -> starter c
      | Some a4 -> (
          match C.nth_after c Wire.Y ~after:a4 0 with
          | None -> battle c
          | Some y when since c y < 1000.0 -> battle c
          | Some y when since c y < 3000.0 -> black c
          | Some y -> andi c ~after:y))

(* 02.01: the alley's party bar until the stick was held 16.75 s; then
   Brigitte's text until two A, the battle HUD until a move, her speech until
   two A, then the plaza's party bar. [no_scene]: after the move, her speech
   box shows over the party bar with no text box, and nothing else follows. *)
let brigitte ?(no_scene = false) c =
  match C.stick_reached c 16_750 with
  | None -> party c
  | Some w -> (
      match C.nth_after c Wire.A ~after:w 1 with
      | None -> text c
      | Some a2 -> (
          match C.nth_after c Wire.Y ~after:a2 0 with
          | None -> battle c
          | Some _ when no_scene -> { (party c) with story_dialog = true }
          | Some y -> andi c ~after:y))

(* 02.02: the plaza's party bar until the stick was held 6.5 s; a black fade
   for 1 s, the cutscene until + is held, the skip's black fade, the street
   scene's text until two A, the party bar; the gate's A prompt once the stick
   reached 9.5 s, until A; Taunie's text until two more A, the party bar; the
   Hotel Z arrival's text once the stick reached 16.5 s, until two A, then the
   party bar. [lost]: no fade, the party bar alone. *)
let arrival_at_hotel c ~after =
  match C.nth_after c Wire.A ~after 2 with
  | None -> text c
  | Some _ -> (
      match C.stick_reached c 16_500 with
      | None -> party c
      | Some h -> (
          match C.nth_after c Wire.A ~after:h 1 with
          | None -> text c
          | Some _ -> party c))

let gate c =
  match C.stick_reached c 9500 with
  | None -> party c
  | Some g -> (
      match C.nth_after c Wire.A ~after:g 0 with
      | None -> { (party c) with interact_prompt = true }
      | Some a -> arrival_at_hotel c ~after:a)

let street c ~fade =
  match C.nth_after c Wire.Plus ~after:fade 0 with
  | None -> look c
  | Some s when since c s < 800.0 -> black c
  | Some s -> (
      match C.nth_after c Wire.A ~after:s 1 with
      | None -> text c
      | Some _ -> gate c)

let hotel_z ?(lost = false) c =
  match C.stick_reached c 6500 with
  | Some f when not lost ->
      if since c f < 1000.0 then black c else street c ~fade:f
  | _ -> party c

(* 02.03: the party bar in front of Hotel Z; the door's A prompt over it once
   the stick was held 2 s, until A; a black fade 1.5 s, the lobby's text until
   two A, then the party bar. [lost]: no prompt. *)
let lobby ?(lost = false) c =
  match C.stick_reached c 2000 with
  | Some p when not lost -> (
      match C.nth_after c Wire.A ~after:p 0 with
      | None -> { (party c) with interact_prompt = true }
      | Some a when since c a < 1500.0 -> black c
      | Some a -> (
          match C.nth_after c Wire.A ~after:a 2 with
          | None -> text c
          | Some _ -> party c))
  | _ -> party c

(* 02.04: the lobby's party bar; the clerk's A prompt once the stick was held
   2.5 s and the turn faced (L presses after it), until A; the check-in's
   text until three A, then the party bar. [lost]: no prompt. *)
let clerk ?(lost = false) c =
  match C.stick_reached c 2500 with
  | Some w when not lost -> (
      match C.nth_after c Wire.L ~after:w 1 with
      | None -> party c
      | Some _ -> (
          match C.nth_after c Wire.A ~after:w 0 with
          | None -> { (party c) with interact_prompt = true }
          | Some a -> (
              match C.nth_after c Wire.A ~after:a 3 with
              | None -> text c
              | Some _ -> party c)))
  | _ -> party c

(* 02.05: the lobby's party bar; the elevator's A prompt once the stick was
   held 2 s, until A; "Which floor?" until A, the choice until A, the ride's
   black fade 1.5 s, the party bar on 2F; Room 202's A prompt once the stick
   was held 4 s, until A, a black fade 1.5 s, the party bar. [lost]: no
   elevator prompt. *)
let room_202 c =
  match C.stick_reached c 4000 with
  | None -> party c
  | Some p -> (
      match C.nth_after c Wire.A ~after:p 0 with
      | None -> { (party c) with interact_prompt = true }
      | Some a when since c a < 1500.0 -> black c
      | Some _ -> party c)

let elevator ?(lost = false) c =
  match C.stick_reached c 2000 with
  | Some e when not lost -> (
      let a n = C.nth_after c Wire.A ~after:e n in
      match (a 0, a 1, a 2) with
      | None, _, _ -> { (party c) with interact_prompt = true }
      | Some _, None, _ -> text c
      | Some _, Some a1, None -> choice c ~after:a1
      | Some _, Some _, Some r when since c r < 1500.0 -> black c
      | Some _, Some _, Some _ -> room_202 c)
  | _ -> party c

(* 02.06: the room's party bar; a passing prompt over it from 300 ms of stick
   to 600 ms, the bed's A prompt from 1 s, until A; "Rest until tomorrow
   morning?" until A, the choice until A, the night's black fade 2 s, text
   until one A, then the party bar. [lost]: the passing prompt only. *)
let bed ?(lost = false) c =
  let prompt = { (party c) with interact_prompt = true } in
  match
    (C.stick_reached c 300, C.stick_reached c 600, C.stick_reached c 1000)
  with
  | None, _, _ -> party c
  | Some _, None, _ -> prompt
  | Some _, Some _, None -> party c
  | Some _, Some _, Some _ when lost -> party c
  | Some _, Some _, Some b -> (
      let a n = C.nth_after c Wire.A ~after:b n in
      match (a 0, a 1, a 2, a 3) with
      | None, _, _, _ -> prompt
      | Some _, None, _, _ -> text c
      | Some _, Some a1, None, _ -> choice c ~after:a1
      | Some _, Some _, Some r, _ when since c r < 2000.0 -> black c
      | Some _, Some _, Some _, None -> text c
      | Some _, Some _, Some _, Some _ -> party c)

(* 02.07: the room's party bar; the door's A prompt once the stick was held
   1.6 s, until A; a black fade 1.5 s, the evening's text until three A, then
   the party bar. [lost]: no prompt. *)
let room_door ?(lost = false) c =
  match C.stick_reached c 1600 with
  | Some d when not lost -> (
      match C.nth_after c Wire.A ~after:d 0 with
      | None -> { (party c) with interact_prompt = true }
      | Some a when since c a < 1500.0 -> black c
      | Some a -> (
          match C.nth_after c Wire.A ~after:a 2 with
          | None -> text c
          | Some _ -> party c))
  | _ -> party c

let run_plan (p : Plan.t) screen =
  let c = C.create () in
  reloaded := false;
  let reload () =
    reloaded := true;
    c.now <- c.now +. 30_000.0;
    Ok ()
  in
  let game =
    Plza_autostory.Story_game.make (C.steps c screen) ~checkpoint:p.checkpoint
      ~reload
  in
  match Runner.run game p.checkpoint with
  | Ok () -> "passed"
  | Error f -> Failure.to_string f

let result checkpoint screen () = run_plan (plan checkpoint) screen

(* The run on [screen]: its end and the console. *)
let outcome checkpoint screen =
  let c = C.create () in
  let game =
    Plza_autostory.Story_game.make (C.steps c screen)
      ~checkpoint:(plan checkpoint).checkpoint ~reload:(fun () -> Ok ())
  in
  ( (match Runner.run game (plan checkpoint).checkpoint with
    | Ok () -> "passed"
    | Error f -> Failure.to_string f),
    c )

let logged checkpoint screen part () =
  let _, c = outcome checkpoint screen in
  string_of_bool
    (List.exists (fun line -> Strings.Contains.substring line part) (C.lines c))

(* The events the run on [screen] skipped, by their skip_if. *)
let skipped checkpoint screen () =
  let _, c = outcome checkpoint screen in
  let event line =
    Option.map
      (fun word -> String.concat "" (String.split_on_char ':' word))
      (List.nth_opt (String.split_on_char ' ' line) 3)
  in
  String.concat " "
    (List.filter_map
       (fun line ->
         if Strings.Contains.substring line ": skipped (" then event line
         else None)
       (C.lines c))

(* 01.04's battle jump: the walk ends on the battle HUD. *)
let jump_lines () =
  let cp = (plan "01.04-starter-and-andi").checkpoint in
  let ev id = List.find (fun (e : Plan.event) -> e.id = id) cp.events in
  let lines = ref [] in
  let jump =
    Plza_autostory.Battle_jump.make cp ~log:(fun l -> lines := l :: !lines)
  in
  let ran id =
    ignore
      (Plza_autostory.Battle_jump.run jump (ev id) (fun () ->
           lines := ("ran " ^ id) :: !lines;
           Ok ())
        : (unit, Engine_run.Failure.cause) result)
  in
  ignore
    (Plza_autostory.Battle_jump.after jump (ev "approach_starter")
       (Error Plza_walk.Battle_stop.battle_on_screen)
      : (unit, Engine_run.Failure.cause) result);
  ran "andi_battle_start";
  ran "andi_battle";
  List.rev !lines

(* A plan with a talk after the walk: no handler for it yet. *)
let with_talk () =
  plan_of_text
    {|{"format": "gamepilot-checkpoint/1", "game": "plza", "execution": {},
       "checkpoint": {"id": "01.02-platform-to-plaza", "title": "t",
         "start": {"place": "LumioseCity"},
         "events": [
           {"id": "w", "kind": "walk", "args": {"legs": [[0, 1000]]}},
           {"id": "chat", "kind": "talk"}]}}|}

(* A plan of one game action with [args] (JSON). *)
let one_action action args =
  plan_of_text
    (Printf.sprintf
       {|{"format": "gamepilot-checkpoint/1", "game": "plza", "execution": {},
          "checkpoint": {"id": "02.01-battle-brigitte", "title": "t",
            "start": {"place": "LumioseCity"},
            "events": [
              {"id": "a", "kind": "game_action", "action": %S, "args": %s}]}}|}
       action args)

let one_action_result action args screen () =
  run_plan (one_action action args) screen

module W = Wire.Watch

let state_name = function
  | W.Pending -> "pending"
  | Current -> "current"
  | Done -> "done"
  | Failed -> "failed"
  | Skipped -> "skipped"

let shown_event (e : W.plan_event) =
  e.id ^ "=" ^ state_name e.state
  ^ if e.detail = "" then "" else "(" ^ e.detail ^ ")"

let shown_run (r : Wire.Watch_run.t) =
  String.concat " "
    (("run " ^ r.mode)
    :: List.map
         (fun (c : Wire.Watch_run.checkpoint) ->
           c.id ^ "=" ^ Wire.Watch_run.string_of_state c.state)
         r.checkpoints)

(* What the watch page is sent while [f] runs: each plan and run, in order. *)
let page f =
  let sent = ref [] in
  let add line = sent := line :: !sent in
  let effc : type a.
      a Effect.t -> ((a, unit) Effect.Deep.continuation -> unit) option =
    function
    | Effects.Show_plan p ->
        Some
          (fun k ->
            add
              ("plan " ^ p.checkpoint ^ ": "
              ^ String.concat " " (List.map shown_event p.events));
            Effect.Deep.continue k ())
    | Effects.Show_run r ->
        Some
          (fun k ->
            add (shown_run r);
            Effect.Deep.continue k ())
    | _ -> None
  in
  Effect.Deep.try_with f () { effc };
  List.rev !sent

(* [checkpoint] run with Story_game.run_watched: what the page showed. *)
let watched ?(checkpoint = "01.02-platform-to-plaza") screen =
  page (fun () ->
      let c = C.create () in
      let p = plan checkpoint in
      let game =
        Plza_autostory.Story_game.make (C.steps c screen)
          ~checkpoint:p.checkpoint ~reload:(fun () -> Ok ())
      in
      let report = Plan_watch.create p.checkpoint in
      ignore
        (Plza_autostory.Story_game.run_watched ~mode:"testing" report game
           p.checkpoint))

(* The page's last line, and the one before it. *)
let last_shown ?checkpoint screen () =
  match List.rev (watched ?checkpoint screen) with
  | last :: _ -> last
  | [] -> "nothing"

let last_plan screen () =
  match List.rev (watched screen) with _ :: plan :: _ -> plan | _ -> "nothing"

(* 03.01: the room's party bar; the door's A prompt once the stick was held
   2 s, until A; a black fade 1.5 s, the 2F hall's party bar; the elevator's A
   prompt once the stick was held 4.2 s, until A; "Which floor?" until A, the
   choice until A, the ride's black fade 1.5 s; the lobby's text until two A,
   Alton's choice until A, text until one more A, then the party bar.
   [lost]: no door prompt. *)
let lobby_scene c ~ride =
  let a n = C.nth_after c Wire.A ~after:ride n in
  match (a 1, a 2, a 3) with
  | None, _, _ -> text c
  | Some a2, None, _ -> choice c ~after:a2
  | Some _, Some _, None -> text c
  | Some _, Some _, Some _ -> party c

let down_to_lobby c =
  match C.stick_reached c 4200 with
  | None -> party c
  | Some e -> (
      let a n = C.nth_after c Wire.A ~after:e n in
      match (a 0, a 1, a 2) with
      | None, _, _ -> { (party c) with interact_prompt = true }
      | Some _, None, _ -> text c
      | Some _, Some a1, None -> choice c ~after:a1
      | Some _, Some _, Some r when since c r < 1500.0 -> black c
      | Some _, Some _, Some r -> lobby_scene c ~ride:r)

let out_of_room ?(lost = false) c =
  match C.stick_reached c 2000 with
  | Some d when not lost -> (
      match C.nth_after c Wire.A ~after:d 0 with
      | None -> { (party c) with interact_prompt = true }
      | Some a when since c a < 1500.0 -> black c
      | Some _ -> down_to_lobby c)
  | _ -> party c

(* 03.02: the lobby's party bar, the front door's A prompt once the stick was
   held 5 s, until A; a black fade 1.5 s, the Main Menu card until A, then the
   party bar outside. [lost]: no door prompt, and A on nothing. *)
let hotel_door ?(lost = false) c =
  match C.stick_reached c 5000 with
  | Some d when not lost -> (
      match C.nth_after c Wire.A ~after:d 0 with
      | None -> { (party c) with interact_prompt = true }
      | Some a when since c a < 1500.0 -> black c
      | Some a when C.nth_after c Wire.A ~after:a 0 = None ->
          { (look c) with tutorial_card = true }
      | Some _ -> party c)
  | _ -> party c

(* 03.03 after Tepig's move [y]: Taunie's speech until A, the Map & Missions
   card until A, the map until B, her talk until B, then the party bar. *)
let map_talk c ~y =
  match C.nth_after c Wire.A ~after:y 0 with
  | None -> { (text c) with story_dialog = true }
  | Some a -> (
      match C.nth_after c Wire.A ~after:a 0 with
      | None -> { (look c) with tutorial_card = true }
      | Some card -> (
          let b n = C.nth_after c Wire.B ~after:card n in
          match (b 0, b 1) with
          | None, _ -> look c
          | Some _, None -> text c
          | Some _, Some _ -> party c))

(* 03.03's battles from the battle HUD after [after]: the HUD until a move;
   "We're not done" until two A, the card until A, the HUD until a second
   move; then the map talk. [ko_fade]: Totodile beaten, the HUD (the lead at
   21/25) 1 s, then a black fade 2 s before "We're not done", as console B's
   French run (2026-11-25) showed it. *)
let taunie_from_battle ?(ko_fade = false) c ~after =
  let y n = C.nth_after c Wire.Y ~after n in
  match (y 0, y 1) with
  | None, _ -> battle c
  | Some y0, None when ko_fade && since c y0 < 1000.0 -> battle c
  | Some y0, None when ko_fade && since c y0 < 3000.0 -> black c
  | Some y0, None -> (
      match
        (C.nth_after c Wire.A ~after:y0 1, C.nth_after c Wire.A ~after:y0 2)
      with
      | None, _ -> { (text c) with story_dialog = true }
      | Some _, None -> { (look c) with tutorial_card = true }
      | Some _, Some _ -> battle c)
  | Some _, Some y1 -> map_talk c ~y:y1

(* 03.03's battles after Taunie's prompt [t]: her text until two A, then
   the battles. *)
let taunie_battles ?ko_fade c ~t =
  match C.nth_after c Wire.A ~after:t 2 with
  | None -> text c
  | Some _ -> taunie_from_battle ?ko_fade c ~after:t

(* 03.03: the plaza's party bar, the scene's A prompt once the stick was held
   4 s, until A; a black fade 1.5 s, the Smart Rotom card until A, the party
   bar at the arch; Taunie's A prompt once the stick was held 7 s, until A;
   then her battles. [lost]: no scene prompt. [battle_mid_walk]: her battle
   starts 2 s into the walk to her (the HUD, no talk), as 03.03's did on
   console B (2026-11-19). [hud_flicker]: the battle HUD on one read of the
   party bar after the card. *)
let quartiere_verde ?(lost = false) ?(battle_mid_walk = false)
    ?(hud_flicker = false) ?ko_fade c =
  let flicker a =
    match C.nth_after c Wire.A ~after:a 0 with
    | Some card -> hud_flicker && since c card < 250.0
    | None -> false
  in
  match C.stick_reached c 4000 with
  | Some p when not lost -> (
      match C.nth_after c Wire.A ~after:p 0 with
      | None -> { (party c) with interact_prompt = true }
      | Some a when since c a < 1500.0 -> black c
      | Some a when C.nth_after c Wire.A ~after:a 0 = None ->
          { (look c) with tutorial_card = true }
      | Some a when flicker a -> { (party c) with battle = true }
      | Some _ when battle_mid_walk -> (
          match C.stick_reached c 6000 with
          | None -> party c
          | Some w -> taunie_from_battle c ~after:w)
      | Some _ -> (
          match C.stick_reached c 7000 with
          | None -> party c
          | Some w -> (
              match C.nth_after c Wire.A ~after:w 0 with
              | None -> { (party c) with interact_prompt = true }
              | Some t -> taunie_battles ?ko_fade c ~t)))
  | _ -> party c

(* 03.03 after 03.02 in a chain (console B, 2026-11-25): 03.02 left the
   hotel, so the first A prompt is Taunie's, once the stick was held 2.75 s,
   until A; then her battles. *)
let taunie_first c =
  match C.stick_reached c 2750 with
  | None -> party c
  | Some w -> (
      match C.nth_after c Wire.A ~after:w 0 with
      | None -> { (party c) with interact_prompt = true }
      | Some t -> taunie_battles c ~t)

(* 03.04: Taunie's text until two A, the party bar; the rock pile's text once
   the stick was held 4 s (the gate walk runs: 7 s of walk is 4.2 s held with
   B), until two A, then the party bar. [lost]: no rock pile scene. *)
let rock_pile ?(lost = false) c =
  match C.nth_after c Wire.A ~after:0.0 1 with
  | None -> text c
  | Some _ -> (
      match C.stick_reached c 4000 with
      | Some r when not lost -> (
          match C.nth_after c Wire.A ~after:r 1 with
          | None -> text c
          | Some _ -> party c)
      | _ -> party c)

(* The inputs that held B with the stick. *)
let runs (c : C.t) =
  List.length
    (List.filter
       (fun (i : C.input) -> i.stick_ms > 0 && List.mem Wire.B i.buttons)
       c.inputs)

(* 03.05: the party bar; the ladder's A prompt once the stick was held 5.5 s
   (the side street's run, 8 s over 1.65, then the steps along the wall),
   until A; the rooftop's text once the stick was held 12 s, until two A, then
   the party bar. [lost]: no ladder prompt. *)
let ladder ?(lost = false) c =
  match C.stick_reached c 5500 with
  | Some l when not lost -> (
      match C.nth_after c Wire.A ~after:l 0 with
      | None -> { (party c) with interact_prompt = true }
      | Some _ -> (
          match C.stick_reached c 12_000 with
          | None -> party c
          | Some r -> (
              match C.nth_after c Wire.A ~after:r 1 with
              | None -> text c
              | Some _ -> party c)))
  | _ -> party c

(* 03.06: the roof's party bar until the stick was held 3 s; then the south
   boulevard's text until two A, then the party bar. [lost]: no scene. *)
let off_the_roof ?(lost = false) c =
  match C.stick_reached c 3000 with
  | Some w when not lost -> (
      match C.nth_after c Wire.A ~after:w 1 with
      | None -> text c
      | Some _ -> party c)
  | _ -> party c

(* 03.07: the party bar; an A prompt once the stick was held 3.9 s (Urbain's
   on the way in the -90 run, then the nurse's once the legs end), until A;
   the Pokedex app and the talks until three B, then the party bar. [lost]: no
   nurse's prompt. *)
let nurse ?(lost = false) c =
  match C.stick_reached c 3900 with
  | Some n when not lost -> (
      match C.nth_after c Wire.A ~after:n 0 with
      | None -> { (party c) with interact_prompt = true }
      | Some a -> (
          match C.nth_after c Wire.B ~after:a 2 with
          | None -> text c
          | Some _ -> party c))
  | _ -> party c

(* 03.08: the party bar while the run is held (15 s of walk is 9.1 s with
   B); then Taunie's text until two A, the Wild Zones card until A, then the
   party bar. [lost]: no scene ever starts. *)
let wild_zones_card ?(lost = false) c =
  match C.stick_reached c 9000 with
  | Some w when not lost -> (
      let a n = C.nth_after c Wire.A ~after:w n in
      match (a 1, a 2) with
      | None, _ -> text c
      | Some _, None -> { (look c) with tutorial_card = true }
      | Some _, Some _ -> party c)
  | _ -> party c

(* The arch where 03.03 ends: free control with the minimap 03.04 starts
   on. *)
let at_arch c = { (party c) with minimap = Some "03.03-start" }

(* Outside the Center, where 03.07 ends and 03.08 starts. *)
let outside_center c = { (party c) with minimap = Some "03.06-start" }

let cause_or_ok = function
  | Ok () -> "ok"
  | Error e -> Engine_run.Failure.cause_to_string e

(* The start check of [checkpoint]'s plan (or [execution]) on [screen]: its
   result, and the console for its log. *)
let start_checked ?execution ?party checkpoint screen =
  let c = C.create () in
  let execution = Option.value execution ~default:(plan checkpoint).execution in
  let party = Option.map (fun n _ -> Some n) party in
  ( cause_or_ok
      (Plza_autostory.Start_signature.check (C.steps ?party c screen)
         ~checkpoint_id:checkpoint execution),
    c )

let start_check ?execution ?party checkpoint screen () =
  fst (start_checked ?execution ?party checkpoint screen)

let start_logged ?party checkpoint screen part () =
  let _, c = start_checked ?party checkpoint screen in
  string_of_bool
    (List.exists (fun line -> Strings.Contains.substring line part) (C.lines c))

(* The end check of [checkpoint]'s plan on [screen]. *)
let end_checked checkpoint screen =
  let c = C.create () in
  ( cause_or_ok
      (Plza_autostory.Start_signature.check_end (C.steps c screen)
         ~checkpoint_id:checkpoint (plan checkpoint).execution),
    c )

let end_check checkpoint screen () = fst (end_checked checkpoint screen)

let end_logged checkpoint screen part () =
  let _, c = end_checked checkpoint screen in
  string_of_bool
    (List.exists (fun line -> Strings.Contains.substring line part) (C.lines c))

(* How many inputs held B with the stick: the walk's runs. *)
let run_count checkpoint screen () =
  let _, c = outcome checkpoint screen in
  string_of_int (runs c)

(* 03.09: the gate's A prompt once the stick was held 4.3 s, then the party
   bar: no Fletchling ever shows. *)
let zone_gate c =
  match C.stick_reached c 4300 with
  | None -> party c
  | Some _ -> { (party c) with interact_prompt = true }

let at_zone_gate c = { (party c) with minimap = Some "03.07-start" }

(* The throws: inputs with ZR. *)
let throws (c : C.t) =
  List.length
    (List.filter (fun (i : C.input) -> List.mem Wire.ZR i.buttons) c.inputs)

(* 03.14: the lobby's party bar; the elevator's A prompt once the stick was
   held 0.8 s (the run: 1.5 s of walk), until A; the attendant's question
   until A, the floors until A (3F after Down), the ride's text until two B,
   then the party bar. [lost]: no elevator prompt. *)
let lab_elevator ?(lost = false) c =
  match C.stick_reached c 800 with
  | Some e when not lost -> (
      let a n = C.nth_after c Wire.A ~after:e n in
      match (a 0, a 1, a 2) with
      | None, _, _ -> { (party c) with interact_prompt = true }
      | Some _, None, _ -> text c
      | Some _, Some q, None -> choice c ~after:q
      | Some _, Some _, Some r -> (
          match C.nth_after c Wire.B ~after:r 1 with
          | None -> text c
          | Some _ -> party c))
  | _ -> party c

(* Wild Zone 1 with the map open (+ since the last B) on [pin], its arrow
   reading [facing]. *)
let map_open c =
  match (C.last_press c Wire.Plus, C.last_press c Wire.B) with
  | Some s, Some b -> s > b
  | Some _, None -> true
  | None, _ -> false

let in_zone ?(facing = 270.) ~pin c =
  if map_open c then
    {
      (look c) with
      map_pin = Some { Plza_walk.Map_leg.x = fst pin; y = snd pin };
    }
  else { (party c) with minimap_arrow = Some facing }

(* 03.12: on the gate's line at (379, 250), facing the gate (264). B held 1 s
   or more brings up the gate's A prompt; A leaves (a black fade for 1.5 s),
   then the street outside, where the map opens on its centre (401, 225). *)
let leave_zone c =
  let held_b =
    List.fold_left
      (fun ms (i : C.input) ->
        if List.mem Wire.B i.buttons then ms + i.stick_ms else ms)
      0 c.C.inputs
  in
  match C.last_press c Wire.A with
  | Some a when c.now < a +. 1500. -> { (look c) with fade_black = true }
  | Some _ -> in_zone ~facing:264. ~pin:(401., 225.) c
  | None when held_b >= 1000 && not (map_open c) -> prompt c
  | None -> in_zone ~facing:264. ~pin:(379., 250.) c

let at_rocks = in_zone ~pin:(476., 224.)
let at_100_spot = in_zone ~pin:(440., 229.)
let out_of_zone = in_zone ~pin:(401., 225.)

(* The inputs a run on [screen] sent. *)
let inputs_sent checkpoint screen () =
  string_of_int (List.length (snd (outcome checkpoint screen)).C.inputs)

let cases =
  [
    case
      "01.01-to-the-platform: Confirm Choices, Ready!, the opening skipped, \
       the platform"
      (result "01.01-to-the-platform" new_game)
      "passed";
    case "01.01-to-the-platform on another screen: nothing pressed, repeats"
      (result "01.01-to-the-platform" (new_game ~confirm:false))
      "01.01-to-the-platform event 1 (confirm): not_on_confirm_choices: 01.01 \
       starts on the new game's \"Confirm Choices\" screen, after the \
       language, look and name (made by hand). It is not on screen; nothing \
       was pressed.";
    case "01.01-to-the-platform on the watch page: its run passes"
      (last_shown ~checkpoint:"01.01-to-the-platform" new_game)
      "run testing 01.01-to-the-platform=passed";
    case "01.02-platform-to-plaza's plan: a zone start and its events"
      (fun () -> Plan_text.outline (plan "01.02-platform-to-plaza"))
      "plza 01.02-platform-to-plaza from LumioseCity: 3 game_action, 1 walk, 2 \
       scene";
    case
      "01.02-platform-to-plaza: the platform to the controls hint after the \
       arrival scenes"
      (result "01.02-platform-to-plaza" platform)
      "passed";
    case "01.02-platform-to-plaza lost: the walk's white fade never shows"
      (result "01.02-platform-to-plaza" (platform ~lost:true))
      "01.02-platform-to-plaza event 3 (platform_to_plaza): walk_no_end: \
       platform_to_plaza: no end event within 11287 ms of the last leg";
    case "01.02-platform-to-plaza with the hint faded: passes"
      (result "01.02-platform-to-plaza" (platform ~faded:true))
      "passed";
    case
      "01.02-platform-to-plaza with the hint faded: the platform wait reloaded"
      (fun () ->
        ignore
          (result "01.02-platform-to-plaza" (platform ~faded:true) () : string);
        string_of_bool !reloaded)
      "true";
    case
      "01.02-platform-to-plaza off the platform: no controls hint, even after \
       a reload"
      (result "01.02-platform-to-plaza" look)
      "01.02-platform-to-plaza event 1 (on_platform): platform_not_seen: No \
       controls hint on 2 looks in a row within 10000 ms.";
    case
      "01.03-chase-pancham: the chase, Pancham's scene to its choice, row 1, \
       Ryon's prompt"
      (result "01.03-chase-pancham" pancham)
      "passed";
    case "01.03-chase-pancham: the scene ends on the choice"
      (logged "01.03-chase-pancham" pancham "[PLZA scene] done on choice.")
      "true";
    case "01.03-chase-pancham: choose_1 reads the highlight on row 0 of 2"
      (logged "01.03-chase-pancham" pancham
         "[PLZA] choose_1: row 0 of 2 highlighted")
      "true";
    case
      "01.03-chase-pancham lost: no scene after the chase, Ryon's prompt alone"
      (result "01.03-chase-pancham" (pancham ~lost:true))
      "01.03-chase-pancham event 2 (pancham_cornered): scene_ended_in_control: \
       scene: the scene ended in control, the party bar up 5000 ms with \
       nothing busy (expecting the choice box, the controls hint).";
    case
      "01.04-starter-and-andi: to Chikorita's prompt, through the cards, Andi \
       beaten"
      (result "01.04-starter-and-andi" starter)
      "passed";
    case "01.04-starter-and-andi: the scene to the battle ends on its HUD"
      (logged "01.04-starter-and-andi" starter "[PLZA scene] done on battle.")
      "true";
    case "01.04-starter-and-andi: the battle picks the super effective move"
      (logged "01.04-starter-and-andi" starter
         "[PLZA] story_battle: Picking Move: Left")
      "true";
    case "01.04-starter-and-andi: the battle ends on Andi's dialogue"
      (logged "01.04-starter-and-andi" starter
         "[PLZA] story_battle: a dialogue box after the attacks: the battle is \
          over.")
      "true";
    case "01.04-starter-and-andi no symbols: ZL never locks on in the battle"
      (result "01.04-starter-and-andi" (starter ~no_symbols:true))
      "01.04-starter-and-andi event 3 (andi_battle): battle_failed: \
       fight_story_battle(): no dialogue after the battle within the timeout.";
    case
      "01.04-starter-and-andi lost: the lead at 1 HP faints, a black fade: \
       battle_lost"
      (result "01.04-starter-and-andi" (starter_lost ~fade_ms:2000.0))
      "01.04-starter-and-andi event 3 (andi_battle): battle_lost: a black fade \
       with the lead's HP near empty: the lead fainted (before any Pokémon \
       Center, the heal and the rematch follow)";
    case "01.04-starter-and-andi lost: the fade logged with the lead's last HP"
      (logged "01.04-starter-and-andi"
         (starter_lost ~fade_ms:2000.0)
         "a black fade, the lead's HP last read 0.04: the battle is lost.")
      "true";
    (* With no HP read before it, a fade is no evidence of a loss: the fight
       goes on, the heal's line reads as the won battle's, and the next scene
       waits for control that never comes. *)
    case
      "01.04-starter-and-andi lost with no HP read: the fade alone is no loss"
      (result "01.04-starter-and-andi"
         (starter_lost ~no_hp:true ~fade_ms:2000.0))
      "01.04-starter-and-andi event 4 (after_andi): scene_timeout: scene: Did \
       not finish within 360 s (expecting the controls hint, the party bar or \
       the A prompt).";
    case
      "01.04-starter-and-andi won, a black fade into Andi's line: a cutscene, \
       fought on"
      (result "01.04-starter-and-andi" starter_won_fade)
      "passed";
    case
      "01.04-starter-and-andi won, a black fade into Andi's line: logged as a \
       cutscene"
      (logged "01.04-starter-and-andi" starter_won_fade
         "a black fade, the lead's HP last read 0.89: a cutscene, fighting on.")
      "true";
    (* A fade shorter than the fight's reads (one per attack, 1.25 s or more
       apart) goes unseen: the heal's line reads as the won battle's. *)
    case
      "01.04-starter-and-andi lost with a fade the reads miss (0.5 s): the \
       next scene fails"
      (result "01.04-starter-and-andi" (starter_lost ~fade_ms:500.0))
      "01.04-starter-and-andi event 4 (after_andi): scene_timeout: scene: Did \
       not finish within 360 s (expecting the controls hint, the party bar or \
       the A prompt).";
    case "01.04-starter-and-andi resumed inside Andi's battle: passes"
      (result "01.04-starter-and-andi" (in_battle ~after:0.0))
      "passed";
    case
      "01.04-starter-and-andi resumed inside Andi's battle: the walk and the \
       scene skipped"
      (skipped "01.04-starter-and-andi" (in_battle ~after:0.0))
      "approach_starter andi_battle_start";
    case "01.04-starter-and-andi resumed at Urbain's heal: passes"
      (result "01.04-starter-and-andi" rematch)
      "passed";
    case "01.04-starter-and-andi resumed at Urbain's heal: the walk skipped"
      (skipped "01.04-starter-and-andi" rematch)
      "approach_starter";
    case
      "01.04-starter-and-andi resumed in the alley after it: every event \
       skipped"
      (skipped "01.04-starter-and-andi" party)
      "approach_starter andi_battle_start andi_battle after_andi";
    case
      "01.04-starter-and-andi's jump: a battle during the walk jumps to the \
       battle"
      (fun () -> List.hd (jump_lines ()))
      "[Event] 01.04-starter-and-andi: battle on screen during \
       approach_starter: jumping to andi_battle, skipping andi_battle_start";
    case "01.04-starter-and-andi's jump: the scene before the battle is not run"
      (fun () ->
        string_of_bool (List.mem "ran andi_battle_start" (jump_lines ())))
      "false";
    case "01.04-starter-and-andi's jump: the battle runs"
      (fun () -> string_of_bool (List.mem "ran andi_battle" (jump_lines ())))
      "true";
    case "a talk: no handler for it yet"
      (fun () -> run_plan (with_talk ()) platform)
      "01.02-platform-to-plaza event 2 (chat): no_handler: chat: PLZA runs no \
       talk, answer or save event";
    case "01.02-platform-to-plaza on the watch page: its run passes"
      (last_shown platform) "run testing 01.02-platform-to-plaza=passed";
    case "01.02-platform-to-plaza lost on the watch page: its run fails"
      (last_shown (platform ~lost:true))
      "run testing 01.02-platform-to-plaza=failed";
    case
      "01.02-platform-to-plaza lost on the watch page: the walk fails with its \
       reason"
      (last_plan (platform ~lost:true))
      "plan 01.02-platform-to-plaza: on_platform=done text_speed_fast=done \
       platform_to_plaza=failed(walk_no_end: platform_to_plaza: no end event \
       within 11287 ms of the last leg) arrival_to_ad=pending skip_ad=pending \
       arrival_scenes=pending";
    case
      "the walk is walked up to 03.03-battle-taunie, run from \
       03.04-rock-pile-scene on"
      (fun () ->
        Printf.sprintf "%b %b %b"
          (Plza_autostory.Story_game.walk_only "01.02-platform-to-plaza")
          (Plza_autostory.Story_game.walk_only "03.03-battle-taunie")
          (Plza_autostory.Story_game.walk_only "03.04-rock-pile-scene"))
      "true true false";
  ]

(* The actions' own failures. *)
let cases_actions =
  [
    case "scene_through_prompt with free control and no A prompt"
      (one_action_result "scene_through_prompt" "{}" party)
      "02.01-battle-brigitte event 1 (a): prompt_not_seen: scene: no A prompt \
       to press through: free control with nothing to take A (the walk before \
       it stopped short?)";
    case "scene_through_prompt with an unknown arg"
      (one_action_result "scene_through_prompt" {|{"stop_at_choice": false}|}
         party)
      "02.01-battle-brigitte event 1 (a): bad_args: a: the only arg is \
       stop_at_choice, true";
    case "scene_with_start_window with no window"
      (one_action_result "scene_with_start_window" "{}" party)
      "02.01-battle-brigitte event 1 (a): bad_args: a: the only arg is \
       start_window_ms, a positive number of ms";
  ]

(* 02.01. *)
let cases_02_01 =
  [
    case
      "02.01-battle-brigitte: the Battle Zone walk, Brigitte's talk, Cleffa \
       beaten, the plaza"
      (result "02.01-battle-brigitte" brigitte)
      "passed";
    case
      "02.01-battle-brigitte logs: [PLZA] battle_zone_to_brigitte: legs done, \
       screen now: dialog_box, advance_arrow"
      (logged "02.01-battle-brigitte" brigitte
         "[PLZA] battle_zone_to_brigitte: legs done, screen now: dialog_box, \
          advance_arrow")
      "true";
    case "02.01-battle-brigitte logs: [PLZA scene] done on battle."
      (logged "02.01-battle-brigitte" brigitte "[PLZA scene] done on battle.")
      "true";
    case "02.01-battle-brigitte logs: [PLZA] story_battle: Picking Move: Left"
      (logged "02.01-battle-brigitte" brigitte
         "[PLZA] story_battle: Picking Move: Left")
      "true";
    case "02.01-battle-brigitte logs: [PLZA scene] done on control."
      (logged "02.01-battle-brigitte" brigitte "[PLZA scene] done on control.")
      "true";
    case
      "02.01-battle-brigitte lost: no Brigitte after the walk, the party bar \
       alone"
      (result "02.01-battle-brigitte" party)
      "02.01-battle-brigitte event 2 (brigitte_battle_start): \
       scene_ended_in_control: scene: the scene ended in control, the party \
       bar up 5000 ms with nothing busy (expecting the battle HUD, the \
       controls hint).";
    case
      "02.01-battle-brigitte with no scene after the battle: the start window \
       passes"
      (result "02.01-battle-brigitte" (brigitte ~no_scene:true))
      "02.01-battle-brigitte event 4 (after_brigitte): scene_never_started: \
       scene: the scene never started (player not at its trigger?): the HUD up \
       and no text, choice, battle or cutscene for 45000 ms (expecting the \
       controls hint, the party bar or the A prompt).";
  ]

(* 02.02. *)
let cases_02_02 =
  [
    case
      "02.02-to-hotel-z: the street's cutscene skipped, the gate, Taunie, \
       Hotel Z"
      (result "02.02-to-hotel-z" hotel_z)
      "passed";
    case
      "02.02-to-hotel-z logs: [PLZA] to_blocked_street: the end event after \
       750 ms of the last leg."
      (logged "02.02-to-hotel-z" hotel_z
         "[PLZA] to_blocked_street: the end event after 750 ms of the last leg.")
      "true";
    case "02.02-to-hotel-z logs: [PLZA] to_blocked_street: ended on: fade_black"
      (logged "02.02-to-hotel-z" hotel_z
         "[PLZA] to_blocked_street: ended on: fade_black")
      "true";
    case
      "02.02-to-hotel-z logs: [PLZA] plus_skip: a black fade 0 ms after the \
       hold."
      (logged "02.02-to-hotel-z" hotel_z
         "[PLZA] plus_skip: a black fade 0 ms after the hold.")
      "true";
    case "02.02-to-hotel-z logs: [PLZA scene] done on control."
      (logged "02.02-to-hotel-z" hotel_z "[PLZA scene] done on control.")
      "true";
    case
      "02.02-to-hotel-z logs: [PLZA] to_battle_zone_gate: A on the A prompt \
       after 3000 ms of the last leg started a talk."
      (logged "02.02-to-hotel-z" hotel_z
         "[PLZA] to_battle_zone_gate: A on the A prompt after 3000 ms of the \
          last leg started a talk.")
      "true";
    case
      "02.02-to-hotel-z logs: [PLZA] to_battle_zone_gate: started on: \
       dialog_box, advance_arrow"
      (logged "02.02-to-hotel-z" hotel_z
         "[PLZA] to_battle_zone_gate: started on: dialog_box, advance_arrow")
      "true";
    case
      "02.02-to-hotel-z logs: [PLZA] through_covered_passage: legs done, \
       screen now: dialog_box, advance_arrow"
      (logged "02.02-to-hotel-z" hotel_z
         "[PLZA] through_covered_passage: legs done, screen now: dialog_box, \
          advance_arrow")
      "true";
    case "02.02-to-hotel-z lost: no black fade into the street"
      (result "02.02-to-hotel-z" (hotel_z ~lost:true))
      "02.02-to-hotel-z event 1 (to_blocked_street): walk_no_end: \
       to_blocked_street: no end event within 3363 ms of the last leg";
  ]

(* 02.03. *)
let cases_02_03 =
  [
    case
      "02.03-hotel-z-lobby: up the steps to the door's prompt, A Enter, the \
       lobby"
      (result "02.03-hotel-z-lobby" lobby)
      "passed";
    case
      "02.03-hotel-z-lobby logs: [PLZA] to_hotel_z_door: the end event after \
       2000 ms of the last leg, before its 3375 ms: passed on the way, on."
      (logged "02.03-hotel-z-lobby" lobby
         "[PLZA] to_hotel_z_door: the end event after 2000 ms of the last leg, \
          before its 3375 ms: passed on the way, on.")
      "true";
    case
      "02.03-hotel-z-lobby logs: [PLZA] to_hotel_z_door: the end event after \
       2250 ms of the last leg, before its 3375 ms: passed on the way, on."
      (logged "02.03-hotel-z-lobby" lobby
         "[PLZA] to_hotel_z_door: the end event after 2250 ms of the last leg, \
          before its 3375 ms: passed on the way, on.")
      "true";
    case
      "02.03-hotel-z-lobby logs: [PLZA] to_hotel_z_door: the end event after \
       2500 ms of the last leg, before its 3375 ms: passed on the way, on."
      (logged "02.03-hotel-z-lobby" lobby
         "[PLZA] to_hotel_z_door: the end event after 2500 ms of the last leg, \
          before its 3375 ms: passed on the way, on.")
      "true";
    case
      "02.03-hotel-z-lobby logs: [PLZA] to_hotel_z_door: the end event after \
       2750 ms of the last leg, before its 3375 ms: passed on the way, on."
      (logged "02.03-hotel-z-lobby" lobby
         "[PLZA] to_hotel_z_door: the end event after 2750 ms of the last leg, \
          before its 3375 ms: passed on the way, on.")
      "true";
    case
      "02.03-hotel-z-lobby logs: [PLZA] to_hotel_z_door: the end event after \
       3000 ms of the last leg, before its 3375 ms: passed on the way, on."
      (logged "02.03-hotel-z-lobby" lobby
         "[PLZA] to_hotel_z_door: the end event after 3000 ms of the last leg, \
          before its 3375 ms: passed on the way, on.")
      "true";
    case
      "02.03-hotel-z-lobby logs: [PLZA] to_hotel_z_door: the end event after \
       3250 ms of the last leg, before its 3375 ms: passed on the way, on."
      (logged "02.03-hotel-z-lobby" lobby
         "[PLZA] to_hotel_z_door: the end event after 3250 ms of the last leg, \
          before its 3375 ms: passed on the way, on.")
      "true";
    case
      "02.03-hotel-z-lobby logs: [PLZA] to_hotel_z_door: the end event after \
       3500 ms of the last leg."
      (logged "02.03-hotel-z-lobby" lobby
         "[PLZA] to_hotel_z_door: the end event after 3500 ms of the last leg.")
      "true";
    case
      "02.03-hotel-z-lobby logs: [PLZA] to_hotel_z_door: ended on: \
       player_can_move, interact_prompt"
      (logged "02.03-hotel-z-lobby" lobby
         "[PLZA] to_hotel_z_door: ended on: player_can_move, interact_prompt")
      "true";
    case "02.03-hotel-z-lobby logs: [PLZA scene] done on control."
      (logged "02.03-hotel-z-lobby" lobby "[PLZA scene] done on control.")
      "true";
    case "02.03-hotel-z-lobby lost: no door prompt"
      (result "02.03-hotel-z-lobby" (lobby ~lost:true))
      "02.03-hotel-z-lobby event 1 (to_hotel_z_door): walk_no_end: \
       to_hotel_z_door: no end event within 5061 ms of the last leg";
  ]

(* 02.04. *)
let cases_02_04 =
  [
    case "02.04-hotel-check-in: along the counter, the clerk's prompt, check-in"
      (result "02.04-hotel-check-in" clerk)
      "passed";
    case
      "02.04-hotel-check-in logs: [PLZA] to_front_counter: A on the A prompt \
       after 0 ms of the last leg started a talk."
      (logged "02.04-hotel-check-in" clerk
         "[PLZA] to_front_counter: A on the A prompt after 0 ms of the last \
          leg started a talk.")
      "true";
    case
      "02.04-hotel-check-in logs: [PLZA] to_front_counter: started on: \
       dialog_box, advance_arrow"
      (logged "02.04-hotel-check-in" clerk
         "[PLZA] to_front_counter: started on: dialog_box, advance_arrow")
      "true";
    case "02.04-hotel-check-in logs: [PLZA scene] done on control."
      (logged "02.04-hotel-check-in" clerk "[PLZA scene] done on control.")
      "true";
    case "02.04-hotel-check-in lost: no clerk's prompt"
      (result "02.04-hotel-check-in" (clerk ~lost:true))
      "02.04-hotel-check-in event 1 (to_front_counter): walk_no_end: \
       to_front_counter: no talk started within 1000 ms after the last leg";
  ]

(* 02.05. *)
let cases_02_05 =
  [
    case "02.05-to-room-202: the elevator, 2F, Room 202"
      (result "02.05-to-room-202" elevator)
      "passed";
    case
      "02.05-to-room-202 logs: [PLZA] to_lobby_elevator: the end event after \
       2000 ms of the last leg."
      (logged "02.05-to-room-202" elevator
         "[PLZA] to_lobby_elevator: the end event after 2000 ms of the last \
          leg.")
      "true";
    case
      "02.05-to-room-202 logs: [PLZA] to_lobby_elevator: ended on: \
       player_can_move, interact_prompt"
      (logged "02.05-to-room-202" elevator
         "[PLZA] to_lobby_elevator: ended on: player_can_move, interact_prompt")
      "true";
    case "02.05-to-room-202 logs: [PLZA scene] done on choice."
      (logged "02.05-to-room-202" elevator "[PLZA scene] done on choice.")
      "true";
    case "02.05-to-room-202 logs: [PLZA] choose_0: row 0 of 2 highlighted"
      (logged "02.05-to-room-202" elevator
         "[PLZA] choose_0: row 0 of 2 highlighted")
      "true";
    case "02.05-to-room-202 logs: [PLZA scene] done on control."
      (logged "02.05-to-room-202" elevator "[PLZA scene] done on control.")
      "true";
    case
      "02.05-to-room-202 logs: [PLZA] to_room_202: the end event after 2000 ms \
       of the last leg."
      (logged "02.05-to-room-202" elevator
         "[PLZA] to_room_202: the end event after 2000 ms of the last leg.")
      "true";
    case
      "02.05-to-room-202 logs: [PLZA] to_room_202: ended on: player_can_move, \
       interact_prompt"
      (logged "02.05-to-room-202" elevator
         "[PLZA] to_room_202: ended on: player_can_move, interact_prompt")
      "true";
    case "02.05-to-room-202 lost: no elevator prompt"
      (result "02.05-to-room-202" (elevator ~lost:true))
      "02.05-to-room-202 event 1 (to_lobby_elevator): walk_no_end: \
       to_lobby_elevator: no end event within 3363 ms of the last leg";
  ]

(* 02.06. *)
let cases_02_06 =
  [
    case "02.06-night-in-room-202: a prompt passed, the bed, rest until morning"
      (result "02.06-night-in-room-202" bed)
      "passed";
    case
      "02.06-night-in-room-202 logs: [PLZA] to_bed: the end event after 500 ms \
       of the last leg, before its 750 ms: passed on the way, on."
      (logged "02.06-night-in-room-202" bed
         "[PLZA] to_bed: the end event after 500 ms of the last leg, before \
          its 750 ms: passed on the way, on.")
      "true";
    case
      "02.06-night-in-room-202 logs: [PLZA] to_bed: the end event after 1000 \
       ms of the last leg."
      (logged "02.06-night-in-room-202" bed
         "[PLZA] to_bed: the end event after 1000 ms of the last leg.")
      "true";
    case
      "02.06-night-in-room-202 logs: [PLZA] to_bed: ended on: player_can_move, \
       interact_prompt"
      (logged "02.06-night-in-room-202" bed
         "[PLZA] to_bed: ended on: player_can_move, interact_prompt")
      "true";
    case "02.06-night-in-room-202 logs: [PLZA scene] done on choice."
      (logged "02.06-night-in-room-202" bed "[PLZA scene] done on choice.")
      "true";
    case "02.06-night-in-room-202 logs: [PLZA] choose_0: row 0 of 2 highlighted"
      (logged "02.06-night-in-room-202" bed
         "[PLZA] choose_0: row 0 of 2 highlighted")
      "true";
    case "02.06-night-in-room-202 logs: [PLZA scene] done on control."
      (logged "02.06-night-in-room-202" bed "[PLZA scene] done on control.")
      "true";
    case "02.06-night-in-room-202 lost: no bed prompt"
      (result "02.06-night-in-room-202" (bed ~lost:true))
      "02.06-night-in-room-202 event 1 (to_bed): walk_no_end: to_bed: no end \
       event within 1665 ms of the last leg";
  ]

(* 02.07. *)
let cases_02_07 =
  [
    case "02.07-first-evening: to the door's prompt, A Leave, the first evening"
      (result "02.07-first-evening" room_door)
      "passed";
    case
      "02.07-first-evening logs: [PLZA] to_room_door: the end event after 1750 \
       ms of the last leg."
      (logged "02.07-first-evening" room_door
         "[PLZA] to_room_door: the end event after 1750 ms of the last leg.")
      "true";
    case
      "02.07-first-evening logs: [PLZA] to_room_door: ended on: \
       player_can_move, interact_prompt"
      (logged "02.07-first-evening" room_door
         "[PLZA] to_room_door: ended on: player_can_move, interact_prompt")
      "true";
    case "02.07-first-evening logs: [PLZA scene] done on control."
      (logged "02.07-first-evening" room_door "[PLZA scene] done on control.")
      "true";
    case "02.07-first-evening lost: no door prompt"
      (result "02.07-first-evening" (room_door ~lost:true))
      "02.07-first-evening event 1 (to_room_door): walk_no_end: to_room_door: \
       no end event within 2231 ms of the last leg";
  ]

(* 03.01. *)
let cases_03_01 =
  [
    case "03.01-down-to-the-lobby: out of Room 202, the elevator, the lobby"
      (result "03.01-down-to-the-lobby" out_of_room)
      "passed";
    case
      "03.01-down-to-the-lobby logs: the door's prompt after 1000 ms of the \
       last leg"
      (logged "03.01-down-to-the-lobby" out_of_room
         "[PLZA] out_of_room_202: the end event after 1000 ms of the last leg.")
      "true";
    case
      "03.01-down-to-the-lobby logs: the elevator's prompt after 2000 ms of \
       the last leg"
      (logged "03.01-down-to-the-lobby" out_of_room
         "[PLZA] to_2f_elevator: the end event after 2000 ms of the last leg.")
      "true";
    case "03.01-down-to-the-lobby logs: the floor question ends on its choice"
      (logged "03.01-down-to-the-lobby" out_of_room
         "[PLZA scene] done on choice.")
      "true";
    case "03.01-down-to-the-lobby logs: choose_0 on row 0 of 2"
      (logged "03.01-down-to-the-lobby" out_of_room
         "[PLZA] choose_0: row 0 of 2 highlighted")
      "true";
    case "03.01-down-to-the-lobby lost: no door prompt"
      (result "03.01-down-to-the-lobby" (out_of_room ~lost:true))
      "03.01-down-to-the-lobby event 1 (out_of_room_202): walk_no_end: \
       out_of_room_202: no end event within 1099 ms of the last leg";
  ]

(* 03.02. *)
let cases_03_02 =
  [
    case "03.02-out-of-hotel-z: across the lobby, A Leave, the Main Menu card"
      (result "03.02-out-of-hotel-z" hotel_door)
      "passed";
    case "03.02-out-of-hotel-z logs: the legs end on the front door's prompt"
      (logged "03.02-out-of-hotel-z" hotel_door
         "[PLZA] to_hotel_front_door: legs done, screen now: player_can_move, \
          interact_prompt")
      "true";
    case "03.02-out-of-hotel-z lost: no front door prompt"
      (result "03.02-out-of-hotel-z" (hotel_door ~lost:true))
      "03.02-out-of-hotel-z event 2 (leave_hotel_z): prompt_not_seen: scene: \
       no A prompt to press through: free control with nothing to take A (the \
       walk before it stopped short?)";
    case
      "03.02-out-of-hotel-z into Taunie's battle, no story battle ahead: the \
       scene goes on through the HUD and times out"
      (result "03.02-out-of-hotel-z" taunie_first)
      "03.02-out-of-hotel-z event 2 (leave_hotel_z): scene_timeout: scene: Did \
       not finish within 360 s (expecting the controls hint, the party bar or \
       the A prompt).";
  ]

(* 03.03. *)
let cases_03_02b =
  [
    case
      "03.03-battle-taunie: the plaza scene, Taunie's two battles, the map talk"
      (result "03.03-battle-taunie" quartiere_verde)
      "passed";
    case
      "03.03-battle-taunie logs: a talk to Taunie started after 3000 ms of the \
       last leg"
      (logged "03.03-battle-taunie" quartiere_verde
         "[PLZA] to_taunie: A on the A prompt after 3000 ms of the last leg \
          started a talk.")
      "true";
    case "03.03-battle-taunie logs: the map talk ends on the party bar"
      (logged "03.03-battle-taunie" quartiere_verde
         "[PLZA] talk_through_map_screen: the party bar held: back in the \
          overworld")
      "true";
    case "03.03-battle-taunie, a black fade before \"We're not done\": passes"
      (result "03.03-battle-taunie" (quartiere_verde ~ko_fade:true))
      "passed";
    case
      "03.03-battle-taunie, a black fade before \"We're not done\": a \
       cutscene, fighting on"
      (logged "03.03-battle-taunie"
         (quartiere_verde ~ko_fade:true)
         "[PLZA] story_battle: a black fade, the lead's HP last read 0.89: a \
          cutscene, fighting on.")
      "true";
    case "03.03-battle-taunie, Taunie's battle mid-walk: passes"
      (result "03.03-battle-taunie" (quartiere_verde ~battle_mid_walk:true))
      "passed";
    case
      "03.03-battle-taunie, Taunie's battle mid-walk: the walk stops on the HUD"
      (logged "03.03-battle-taunie"
         (quartiere_verde ~battle_mid_walk:true)
         "[PLZA] to_taunie: battle HUD showed after 2250 ms of the last leg: \
          stopping walk.")
      "true";
    case
      "03.03-battle-taunie, Taunie's battle mid-walk: the run jumps to the \
       battle"
      (logged "03.03-battle-taunie"
         (quartiere_verde ~battle_mid_walk:true)
         "[Event] 03.03-battle-taunie: battle on screen during to_taunie: \
          jumping to battle_totodile, skipping taunie_battle_start")
      "true";
    case
      "03.03-battle-taunie after 03.02-out-of-hotel-z: Taunie's prompt first, \
       then it passes"
      (result "03.03-battle-taunie" taunie_first)
      "passed";
    case
      "03.03-battle-taunie after 03.02-out-of-hotel-z: the plaza scene ends at \
       her battle"
      (logged "03.03-battle-taunie" taunie_first
         "[Event] 03.03-battle-taunie: battle on screen during plaza_scene: \
          jumping to battle_totodile, skipping to_taunie, taunie_battle_start")
      "true";
    case
      "03.03-battle-taunie with the battle HUD on one read of the plaza scene: \
       passes"
      (result "03.03-battle-taunie" (quartiere_verde ~hud_flicker:true))
      "passed";
    case
      "03.03-battle-taunie with the battle HUD on one read: the scene ends on \
       control"
      (logged "03.03-battle-taunie"
         (quartiere_verde ~hud_flicker:true)
         "[PLZA scene] control at 3.3s: party bar")
      "true";
    case "03.03-battle-taunie lost: no plaza scene prompt"
      (result "03.03-battle-taunie" (quartiere_verde ~lost:true))
      "03.03-battle-taunie event 1 (to_plaza_scene_prompt): walk_no_end: \
       to_plaza_scene_prompt: no end event within 9023 ms of the last leg";
    case "03.03-battle-taunie resumed at the arch after it: passes"
      (result "03.03-battle-taunie" at_arch)
      "passed";
    case "03.03-battle-taunie resumed at the arch after it: every event skipped"
      (skipped "03.03-battle-taunie" at_arch)
      "to_plaza_scene_prompt plaza_scene to_taunie taunie_battle_start \
       battle_totodile tepig_battle_start battle_tepig after_taunie_battle";
    case "03.03-battle-taunie's start, the plaza: nothing skipped"
      (skipped "03.03-battle-taunie" quartiere_verde)
      "";
  ]

(* 03.04 to 03.06. *)
let cases_03_03 =
  [
    case "03.04-rock-pile-scene: Taunie runs off, the gate walk, the rock pile"
      (result "03.04-rock-pile-scene" rock_pile)
      "passed";
    case "03.04-rock-pile-scene: the gate walk runs with B, once"
      (run_count "03.04-rock-pile-scene" rock_pile)
      "1";
    case
      "03.04-rock-pile-scene lost: no rock pile scene, yet it passes (the \
       fork's plain scene)"
      (result "03.04-rock-pile-scene" (rock_pile ~lost:true))
      "passed";
    case "03.05-up-to-the-rooftop: the side street, the ladder, the rooftop"
      (result "03.05-up-to-the-rooftop" ladder)
      "passed";
    case "03.05-up-to-the-rooftop logs: Climb Up after 2 steps along the wall"
      (logged "03.05-up-to-the-rooftop" ladder
         "[PLZA] climb_ladder: Climb Up after 2 steps along the wall")
      "true";
    case "03.05-up-to-the-rooftop lost: no ladder prompt along the wall"
      (result "03.05-up-to-the-rooftop" (ladder ~lost:true))
      "03.05-up-to-the-rooftop event 2 (climb_ladder): ladder_not_found: no \
       Climb Up prompt stepping along the wall";
    case "03.06-off-the-roof: off the roof into the south boulevard scene"
      (result "03.06-off-the-roof" off_the_roof)
      "passed";
    case
      "03.06-off-the-roof logs: a scene took the walk after 5250 ms of the \
       last leg"
      (logged "03.06-off-the-roof" off_the_roof
         "[PLZA] off_the_roof: a scene (text waiting for A) took control after \
          5250 ms of the last leg: the walk stops.")
      "true";
    case "03.06-off-the-roof lost: no scene takes the walk"
      (result "03.06-off-the-roof" (off_the_roof ~lost:true))
      "03.06-off-the-roof event 1 (off_the_roof): walk_no_scene: off_the_roof: \
       control still free after 8162 ms of the last leg: no scene took it";
  ]

(* 03.07 and 03.08. *)
let cases_03_04 =
  [
    case
      "03.07-pokemon-center: into the Pokemon Center, the nurse, the Pokedex \
       with B"
      (result "03.07-pokemon-center" nurse)
      "passed";
    case
      "03.07-pokemon-center logs: a talk started on the A prompt after the legs"
      (logged "03.07-pokemon-center" nurse
         "[PLZA] into_pokemon_center: A on the A prompt after 0 ms of the last \
          leg started a talk.")
      "true";
    case "03.07-pokemon-center lost: no nurse's prompt"
      (result "03.07-pokemon-center" (nurse ~lost:true))
      "03.07-pokemon-center event 1 (into_pokemon_center): walk_no_end: \
       into_pokemon_center: no talk started within 1000 ms after the last leg";
    case "03.07-pokemon-center resumed outside the Center: passes"
      (result "03.07-pokemon-center" outside_center)
      "passed";
    case "03.07-pokemon-center resumed outside the Center: every event skipped"
      (skipped "03.07-pokemon-center" outside_center)
      "into_pokemon_center pokedex_app";
    case
      "03.08-wild-zones-card: on to Wild Zone 1's gate, Taunie, the Wild Zones \
       card"
      (result "03.08-wild-zones-card" wild_zones_card)
      "passed";
    case "03.08-wild-zones-card: the walk runs with B, once"
      (run_count "03.08-wild-zones-card" wild_zones_card)
      "1";
    case "03.08-wild-zones-card lost: no scene within the start window"
      (result "03.08-wild-zones-card" (wild_zones_card ~lost:true))
      "03.08-wild-zones-card event 2 (wild_zones_tutorial): \
       scene_never_started: scene: the scene never started (player not at its \
       trigger?): the HUD up and no text, choice, battle or cutscene for 45000 \
       ms (expecting the controls hint, the party bar or the A prompt).";
  ]

(* The start and end signatures (Start_signature). *)
let cases_signatures =
  [
    case "03.04-rock-pile-scene's start check at the arch: ok"
      (start_check "03.04-rock-pile-scene" at_arch)
      "ok";
    case "03.04-rock-pile-scene's start check at the arch: logged as checked"
      (start_logged "03.04-rock-pile-scene" at_arch
         "[Checkpoint] 03.04-rock-pile-scene: START CHECKED: the screen reads \
          (no talk prompt, minimap 03.03-start), its start is (minimap \
          03.03-start)")
      "true";
    case "03.04-rock-pile-scene's start check with no minimap: chain_off_start"
      (start_check "03.04-rock-pile-scene" party)
      "chain_off_start: the run is not at 03.04-rock-pile-scene's start: the \
       screen reads (no talk prompt), its start is (minimap 03.03-start)";
    case "03.07-pokemon-center's start check at its end, outside the Center: ok"
      (start_check "03.07-pokemon-center" outside_center)
      "ok";
    case
      "03.07-pokemon-center's start check at its end: logged as checked at its \
       end"
      (start_logged "03.07-pokemon-center" outside_center
         "[Checkpoint] 03.07-pokemon-center: START CHECKED (at its end)")
      "true";
    case "03.07-pokemon-center's start check at the arch: chain_off_start"
      (start_check "03.07-pokemon-center" at_arch)
      "chain_off_start: the run is not at 03.07-pokemon-center's start: the \
       screen reads (no talk prompt, minimap 03.03-start), its start is \
       (minimap 03.04-start) or its end (minimap 03.06-start)";
    case "03.08-wild-zones-card's start check outside the Center: ok"
      (start_check "03.08-wild-zones-card" outside_center)
      "ok";
    case "03.02-out-of-hotel-z's start: no signature, ok"
      (start_check "03.02-out-of-hotel-z" party)
      "ok";
    case "03.02-out-of-hotel-z's start: logged as unchecked"
      (start_logged "03.02-out-of-hotel-z" party
         "[Checkpoint] 03.02-out-of-hotel-z: START UNCHECKED: its plan names \
          no start signature")
      "true";
    case "03.07-pokemon-center's end check outside the Center: ok"
      (end_check "03.07-pokemon-center" outside_center)
      "ok";
    case
      "03.07-pokemon-center's end check outside the Center: logged as checked"
      (end_logged "03.07-pokemon-center" outside_center
         "[Checkpoint] 03.07-pokemon-center: END CHECKED")
      "true";
    case
      "03.07-pokemon-center's end check inside the Center (Urbain's line): \
       end_off_signature"
      (end_check "03.07-pokemon-center" party)
      "end_off_signature: 03.07-pokemon-center passed its events but did not \
       end at its end: the screen reads (no talk prompt), its end is (minimap \
       03.06-start)";
    case "03.04-rock-pile-scene's end check: none named, ok"
      (end_check "03.04-rock-pile-scene" party)
      "ok";
    case "a start signature with another field: refused"
      (start_check
         ~execution:
           [ ("start_signature", `Assoc [ ("weather", `String "sun") ]) ]
         "03.04-rock-pile-scene" at_arch)
      "start_signature_unread: 03.04-rock-pile-scene: its start signature has \
       \"weather\": its fields are talk_prompt, wild_zone and near_rocks (true \
       or false), party (a count) and minimap (a recorded name)";
    case "a start signature naming an unrecorded minimap: refused"
      (start_check
         ~execution:
           [
             ("start_signature", `Assoc [ ("minimap", `String "03.05-start") ]);
           ]
         "03.04-rock-pile-scene" at_arch)
      "start_signature_unread: 03.04-rock-pile-scene: its start signature \
       names minimap 03.05-start, which is not recorded";
    case "a start signature naming nothing: refused"
      (start_check
         ~execution:[ ("start_signature", `Assoc []) ]
         "03.04-rock-pile-scene" at_arch)
      "start_signature_unread: 03.04-rock-pile-scene: its start signature \
       names nothing";
  ]

let cases_03_07_to_03_11 =
  [
    case "03.09-first-catches' start at Wild Zone 1's gate: ok"
      (start_check "03.09-first-catches" at_zone_gate)
      "ok";
    case "03.09-first-catches' start elsewhere: chain_off_start"
      (start_check "03.09-first-catches" outside_center)
      "chain_off_start: the run is not at 03.09-first-catches's start: the \
       screen reads (no talk prompt, minimap 03.06-start), its start is \
       (minimap 03.07-start)";
    case "03.09-first-catches with no Fletchling to catch: no_catch"
      (result "03.09-first-catches" zone_gate)
      "03.09-first-catches event 3 (catch_fletchling): no_catch: no tutorial \
       card after 6 throws";
    case "03.09-first-catches with no Fletchling to catch: 6 throws"
      (fun () ->
        string_of_int (throws (snd (outcome "03.09-first-catches" zone_gate))))
      "6";
    case "03.14-lab-elevator: the lab's elevator to 3F"
      (result "03.14-lab-elevator" lab_elevator)
      "passed";
    case "03.14-lab-elevator: the walk ends on the elevator's A prompt"
      (logged "03.14-lab-elevator" lab_elevator
         "to_lab_elevator: ended on: player_can_move, interact_prompt")
      "true";
    case "03.14-lab-elevator: choose_1 reads the floors"
      (logged "03.14-lab-elevator" lab_elevator
         "choose_1: row 0 of 2 highlighted")
      "true";
    case "03.14-lab-elevator lost: no elevator prompt"
      (result "03.14-lab-elevator" (lab_elevator ~lost:true))
      "03.14-lab-elevator event 1 (to_lab_elevator): walk_no_end: \
       to_lab_elevator: no end event within 1538 ms of the last leg";
  ]

let cases_03_08_to_03_09 =
  [
    case
      "03.10-fourth-species with no map pin: off its start, the rocks not left"
      (result "03.10-fourth-species" party)
      "03.10-fourth-species event 1 (catch_more_species): chain_off_start: \
       rocks not left: the pin at the start was not read, not within 8 of \
       (476, 224)";
    case "03.10-fourth-species with no map pin: only the map's + and B pressed"
      (inputs_sent "03.10-fourth-species" party)
      "2";
    case "03.10-fourth-species' start at Taunie's rocks with a party of 3: ok"
      (start_check ~party:3 "03.10-fourth-species" at_rocks)
      "ok";
    case "03.10-fourth-species' start at Taunie's rocks: the pin logged"
      (start_logged ~party:3 "03.10-fourth-species" at_rocks
         "[PLZA] map pin: (476, 224)")
      "true";
    case "03.10-fourth-species' start out of the zone: chain_off_start"
      (start_check ~party:3 "03.10-fourth-species" (in_zone ~pin:(401., 224.)))
      "chain_off_start: the run is not at 03.10-fourth-species's start: the \
       screen reads (no talk prompt, not in a wild zone, not near Taunie's \
       rocks, party 3), its start is (in a wild zone, near Taunie's rocks, \
       party 3)";
    case
      "03.10-fourth-species' start at the 100 spot, where a run stopped: \
       chain_off_start"
      (start_check ~party:3 "03.10-fourth-species" at_100_spot)
      "chain_off_start: the run is not at 03.10-fourth-species's start: the \
       screen reads (no talk prompt, in a wild zone, not near Taunie's rocks, \
       party 3), its start is (in a wild zone, near Taunie's rocks, party 3)";
    case "03.10-fourth-species' start with a party of 4: chain_off_start"
      (start_check ~party:4 "03.10-fourth-species" at_rocks)
      "chain_off_start: the run is not at 03.10-fourth-species's start: the \
       screen reads (no talk prompt, in a wild zone, near Taunie's rocks, \
       party 4), its start is (in a wild zone, near Taunie's rocks, party 3)";
    case
      "03.10-fourth-species off Taunie's rocks: off its start, a reload's to \
       fix"
      (fun () ->
        let c = C.create () in
        let p = plan "03.10-fourth-species" in
        let game =
          Plza_autostory.Story_game.make (C.steps c at_100_spot)
            ~checkpoint:p.checkpoint ~reload:(fun () -> Ok ())
        in
        match Runner.run game p.checkpoint with
        | Ok () -> "passed"
        | Error f -> (
            match Plza_autostory.Run_attempts.of_failure f with
            | Passed -> "passed"
            | Failed f -> string_of_bool f.off_start))
      "true";
    case "03.10-fourth-species retries spawn luck: 2"
      (fun () -> string_of_int (plan "03.10-fourth-species").retries)
      "2";
    case "03.11-fifth-species retries spawn luck: 2"
      (fun () -> string_of_int (plan "03.11-fifth-species").retries)
      "2";
    case
      "03.11-fifth-species with no map pin: off its start, the rocks not left"
      (result "03.11-fifth-species" party)
      "03.11-fifth-species event 1 (catch_fifth_species): chain_off_start: \
       rocks not left: the pin at the start was not read, not within 8 of \
       (476, 224)";
    case
      "03.12-out-of-wild-zone-1: down the gate's line to the A prompt, out, \
       checked"
      (result "03.12-out-of-wild-zone-1" leave_zone)
      "passed";
    case "03.12-out-of-wild-zone-1: faces the gate before the run"
      (logged "03.12-out-of-wild-zone-1" leave_zone
         "face_heading: the arrow reads 264.0 deg, 264 wanted")
      "true";
    case "03.12-out-of-wild-zone-1: reaches the gate's A prompt"
      (logged "03.12-out-of-wild-zone-1" leave_zone
         "run_to_gate: the gate's A prompt: reached the gate")
      "true";
    case "03.12-out-of-wild-zone-1: out of Wild Zone 1 by the map pin"
      (logged "03.12-out-of-wild-zone-1" leave_zone
         "out of Wild Zone 1: the map pin reads (401, 225)")
      "true";
    case "03.12-out-of-wild-zone-1 with no gate prompt: gate_not_reached"
      (result "03.12-out-of-wild-zone-1"
         (in_zone ~facing:264. ~pin:(379., 250.)))
      "03.12-out-of-wild-zone-1 event 1 (zone_1_to_far_gate): \
       gate_not_reached: no gate A prompt in 5000 ms of running";
    case
      "03.12-out-of-wild-zone-1 with no gate prompt: runs again from the line"
      (logged "03.12-out-of-wild-zone-1"
         (in_zone ~facing:264. ~pin:(379., 250.))
         "run_out_of_zone_1: no prompt on run 2, again from (379, 250)")
      "true";
    case
      "03.13-into-research-lab's start: out of the zone with a party of 5: ok"
      (start_check ~party:5 "03.13-into-research-lab" out_of_zone)
      "ok";
    case "03.13-into-research-lab's start in the zone: chain_off_start"
      (start_check ~party:5 "03.13-into-research-lab" at_rocks)
      "chain_off_start: the run is not at 03.13-into-research-lab's start: the \
       screen reads (no talk prompt, in a wild zone, party 5), its start is \
       (not in a wild zone, party 5)";
    case
      "03.13-into-research-lab with no minimap arrow: arrow_unread before any \
       leg"
      (result "03.13-into-research-lab" look)
      "03.13-into-research-lab event 1 (to_research_lab): arrow_unread: no \
       minimap arrow within 40 s";
    case "03.13-into-research-lab with no minimap arrow: nothing pressed"
      (inputs_sent "03.13-into-research-lab" look)
      "0";
  ]

let () =
  Table_test.run "plza_story_game"
    (cases @ cases_actions @ cases_02_01 @ cases_02_02 @ cases_02_03
   @ cases_02_04 @ cases_02_05 @ cases_02_06 @ cases_02_07 @ cases_03_01
   @ cases_03_02 @ cases_03_02b @ cases_03_03 @ cases_03_04 @ cases_signatures
   @ cases_03_07_to_03_11 @ cases_03_08_to_03_09)
