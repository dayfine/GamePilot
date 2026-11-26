(* 01.00b to 01.03 run through the engine (Plza_engine.Runner) with
   Story_game's handlers on a scripted console (Fake_console): the plans
   decode, every event reaches its handler, and each handler's presses move a
   game that answers them as the console did. Also the failures: a start that
   is not Confirm Choices, a walk whose white fade never shows (lost), a
   platform never seen, a scene with no choice, a battle with no symbols or
   lost, an event PLZA has no handler for yet; 01.03 resumed by its skip_if
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

(* 01.00b: Confirm Choices on row 0 until A on row 2; a black fade; the
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

(* 01.01: the platform; the menu from X until B; the walk's white fade once
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

(* 01.02: free control (the hint) until the stick was held 20 s; then
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

(* 01.03: Urbain's prompt (control) until the stick was held 600 ms; then
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

(* 01.03 again after a lost battle: inside the battle (its HUD until a move),
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

(* 01.03 lost: the battle with the symbols until a move; then the lead
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

(* 01.03 won, the lead healthy: after the move, the HUD 1 s, then a black
   fade 2 s into Andi's line (as a won battle's cutscene shows one: 03.02b,
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

(* Whether [part] is in [line]. *)
let contains part line =
  let n = String.length part in
  let rec at i =
    i + n <= String.length line && (String.sub line i n = part || at (i + 1))
  in
  at 0

(* Whether a line of the run on [screen] has [part]. *)
let logged checkpoint screen part () =
  let _, c = outcome checkpoint screen in
  string_of_bool (List.exists (contains part) (C.lines c))

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
       (fun line -> if contains ": skipped (" line then event line else None)
       (C.lines c))

(* 01.03's battle jump: the walk ends on the battle HUD. *)
let jump_lines () =
  let cp = (plan "01.03").checkpoint in
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
       "checkpoint": {"id": "01.01", "title": "t",
         "start": {"place": "LumioseCity"},
         "events": [
           {"id": "w", "kind": "walk", "args": {"legs": [[0, 1000]]}},
           {"id": "chat", "kind": "talk"}]}}|}

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
let watched ?(checkpoint = "01.01") screen =
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

let cases =
  [
    case "01.00b: Confirm Choices, Ready!, the opening skipped, the platform"
      (result "01.00b" new_game) "passed";
    case "01.00b on another screen: nothing pressed, repeats"
      (result "01.00b" (new_game ~confirm:false))
      "01.00b event 1 (confirm): not_on_confirm_choices: 01.00b starts on the \
       new game's \"Confirm Choices\" screen, after the language, look and \
       name (made by hand). It is not on screen; nothing was pressed.";
    case "01.00b on the watch page: its run passes"
      (last_shown ~checkpoint:"01.00b" new_game)
      "run testing 01.00b=passed";
    case "01.01's plan: a zone start and its events"
      (fun () -> Plan_text.outline (plan "01.01"))
      "plza 01.01 from LumioseCity: 3 game_action, 1 walk, 2 scene";
    case "01.01: the platform to the controls hint after the arrival scenes"
      (result "01.01" platform) "passed";
    case "01.01 lost: the walk's white fade never shows"
      (result "01.01" (platform ~lost:true))
      "01.01 event 3 (platform_to_plaza): walk_no_end: platform_to_plaza: no \
       end event within 11287 ms of the last leg";
    case "01.01 with the hint faded: passes"
      (result "01.01" (platform ~faded:true))
      "passed";
    case "01.01 with the hint faded: the platform wait reloaded"
      (fun () ->
        ignore (result "01.01" (platform ~faded:true) () : string);
        string_of_bool !reloaded)
      "true";
    case "01.01 off the platform: no controls hint, even after a reload"
      (result "01.01" look)
      "01.01 event 1 (on_platform): platform_not_seen: No controls hint on 2 \
       looks in a row within 10000 ms.";
    case "01.02: the chase, Pancham's scene to its choice, row 1, Ryon's prompt"
      (result "01.02" pancham) "passed";
    case "01.02: the scene ends on the choice"
      (logged "01.02" pancham "[PLZA scene] done on choice.")
      "true";
    case "01.02: choose_1 reads the highlight on row 0 of 2"
      (logged "01.02" pancham "[PLZA] choose_1: row 0 of 2 highlighted")
      "true";
    case "01.02 lost: no scene after the chase, Ryon's prompt alone"
      (result "01.02" (pancham ~lost:true))
      "01.02 event 2 (pancham_cornered): scene_ended_in_control: scene: the \
       scene ended in control, the party bar up 5000 ms with nothing busy \
       (expecting the choice box, the controls hint).";
    case "01.03: to Chikorita's prompt, through the cards, Andi beaten"
      (result "01.03" starter) "passed";
    case "01.03: the scene to the battle ends on its HUD"
      (logged "01.03" starter "[PLZA scene] done on battle.")
      "true";
    case "01.03: the battle picks the super effective move"
      (logged "01.03" starter "[PLZA] story_battle: Picking Move: Left")
      "true";
    case "01.03: the battle ends on Andi's dialogue"
      (logged "01.03" starter
         "[PLZA] story_battle: a dialogue box after the attacks: the battle is \
          over.")
      "true";
    case "01.03 no symbols: ZL never locks on in the battle"
      (result "01.03" (starter ~no_symbols:true))
      "01.03 event 3 (andi_battle): battle_failed: fight_story_battle(): no \
       dialogue after the battle within the timeout.";
    case "01.03 lost: the lead at 1 HP faints, a black fade: battle_lost"
      (result "01.03" (starter_lost ~fade_ms:2000.0))
      "01.03 event 3 (andi_battle): battle_lost: a black fade with the lead's \
       HP near empty: the lead fainted (before any Pokémon Center, the heal \
       and the rematch follow)";
    case "01.03 lost: the fade logged with the lead's last HP"
      (logged "01.03"
         (starter_lost ~fade_ms:2000.0)
         "a black fade, the lead's HP last read 0.04: the battle is lost.")
      "true";
    (* With no HP read before it, a fade is no evidence of a loss: the fight
       goes on, the heal's line reads as the won battle's, and the next scene
       waits for control that never comes. *)
    case "01.03 lost with no HP read: the fade alone is no loss"
      (result "01.03" (starter_lost ~no_hp:true ~fade_ms:2000.0))
      "01.03 event 4 (after_andi): scene_timeout: scene: Did not finish within \
       360 s (expecting the controls hint, the party bar or the A prompt).";
    case "01.03 won, a black fade into Andi's line: a cutscene, fought on"
      (result "01.03" starter_won_fade)
      "passed";
    case "01.03 won, a black fade into Andi's line: logged as a cutscene"
      (logged "01.03" starter_won_fade
         "a black fade, the lead's HP last read 0.89: a cutscene, fighting on.")
      "true";
    (* A fade shorter than the fight's reads (one per attack, 1.25 s or more
       apart) goes unseen: the heal's line reads as the won battle's. *)
    case "01.03 lost with a fade the reads miss (0.5 s): the next scene fails"
      (result "01.03" (starter_lost ~fade_ms:500.0))
      "01.03 event 4 (after_andi): scene_timeout: scene: Did not finish within \
       360 s (expecting the controls hint, the party bar or the A prompt).";
    case "01.03 resumed inside Andi's battle: passes"
      (result "01.03" (in_battle ~after:0.0))
      "passed";
    case "01.03 resumed inside Andi's battle: the walk and the scene skipped"
      (skipped "01.03" (in_battle ~after:0.0))
      "approach_starter andi_battle_start";
    case "01.03 resumed at Urbain's heal: passes" (result "01.03" rematch)
      "passed";
    case "01.03 resumed at Urbain's heal: the walk skipped"
      (skipped "01.03" rematch) "approach_starter";
    case "01.03 resumed in the alley after it: every event skipped"
      (skipped "01.03" party)
      "approach_starter andi_battle_start andi_battle after_andi";
    case "01.03's jump: a battle during the walk jumps to the battle"
      (fun () -> List.hd (jump_lines ()))
      "[Event] 01.03: battle on screen during approach_starter: jumping to \
       andi_battle, skipping andi_battle_start";
    case "01.03's jump: the scene before the battle is not run"
      (fun () ->
        string_of_bool (List.mem "ran andi_battle_start" (jump_lines ())))
      "false";
    case "01.03's jump: the battle runs"
      (fun () -> string_of_bool (List.mem "ran andi_battle" (jump_lines ())))
      "true";
    case "a talk: no handler for it yet"
      (fun () -> run_plan (with_talk ()) platform)
      "01.01 event 2 (chat): no_handler: chat: PLZA runs no talk, answer or \
       save event";
    case "01.01 on the watch page: its run passes" (last_shown platform)
      "run testing 01.01=passed";
    case "01.01 lost on the watch page: its run fails"
      (last_shown (platform ~lost:true))
      "run testing 01.01=failed";
    case "01.01 lost on the watch page: the walk fails with its reason"
      (last_plan (platform ~lost:true))
      "plan 01.01: on_platform=done text_speed_fast=done \
       platform_to_plaza=failed(walk_no_end: platform_to_plaza: no end event \
       within 11287 ms of the last leg) arrival_to_ad=pending skip_ad=pending \
       arrival_scenes=pending";
    case "the walk is walked before 03.03, run after"
      (fun () ->
        Printf.sprintf "%b %b"
          (Plza_autostory.Story_game.walk_only "01.01")
          (Plza_autostory.Story_game.walk_only "03.03"))
      "true false";
  ]

let () = Table_test.run "plza_story_game" cases
