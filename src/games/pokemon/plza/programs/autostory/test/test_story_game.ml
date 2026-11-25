(* 01.00b to 02.07 run through the engine (Plza_checkpoints.Runner) with
   Story_game's handlers on a scripted console (Fake_console): the plans
   decode, every event reaches its handler, and each handler's presses move a
   game that answers them as the console did. Also the failures: a walk whose
   white fade never shows (lost), a start that is not Confirm Choices, a
   platform never seen. And what the watch page is sent (Story_game.run_watched):
   the plan at each event's change and the run. *)

open Plza_checkpoints
module L = Plza_story.Story_look
module C = Fake_console

let case name input expectation = { Table_test.name; input; expectation }

let plan id =
  match
    Plan_decode.decode ~source:(id ^ ".plan.json")
      (Yojson.Safe.from_file (Filename.concat "../plans" (id ^ ".plan.json")))
  with
  | Ok p -> p
  | Error e -> failwith e

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
      match C.nth_after c Wire.Start ~after:a 0 with
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
        match C.nth_after c Wire.Start ~after:a3 0 with
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
   alley's party bar. [no_symbols]: ZL never brings up the symbols. *)
let battle ?(no_symbols = false) c =
  {
    (look c) with
    battle = true;
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
  match C.nth_after c Wire.Start ~after:fade 0 with
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

(* 03.02b after Tepig's move [y]: Taunie's speech until A, the Map & Missions
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

(* 03.02b's battles after Taunie's prompt [t]: her text until two A, the
   battle HUD until a move; "We're not done" until two A, the card until A,
   the HUD until a second move; then the map talk. *)
let taunie_battles c ~t =
  let y n = C.nth_after c Wire.Y ~after:t n in
  match (C.nth_after c Wire.A ~after:t 2, y 0, y 1) with
  | None, _, _ -> text c
  | Some _, None, _ -> battle c
  | Some _, Some y0, None -> (
      match
        (C.nth_after c Wire.A ~after:y0 1, C.nth_after c Wire.A ~after:y0 2)
      with
      | None, _ -> { (text c) with story_dialog = true }
      | Some _, None -> { (look c) with tutorial_card = true }
      | Some _, Some _ -> battle c)
  | Some _, Some _, Some y1 -> map_talk c ~y:y1

(* 03.02b: the plaza's party bar, the scene's A prompt once the stick was held
   4 s, until A; a black fade 1.5 s, the Smart Rotom card until A, the party
   bar at the arch; Taunie's A prompt once the stick was held 7 s, until A;
   then her battles. [lost]: no scene prompt. *)
let quartiere_verde ?(lost = false) c =
  match C.stick_reached c 4000 with
  | Some p when not lost -> (
      match C.nth_after c Wire.A ~after:p 0 with
      | None -> { (party c) with interact_prompt = true }
      | Some a when since c a < 1500.0 -> black c
      | Some a when C.nth_after c Wire.A ~after:a 0 = None ->
          { (look c) with tutorial_card = true }
      | Some _ -> (
          match C.stick_reached c 7000 with
          | None -> party c
          | Some w -> (
              match C.nth_after c Wire.A ~after:w 0 with
              | None -> { (party c) with interact_prompt = true }
              | Some t -> taunie_battles c ~t)))
  | _ -> party c

(* 03.03: Taunie's text until two A, the party bar; the rock pile's text once
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

(* 03.03b: the party bar; the ladder's A prompt once the stick was held 5.5 s
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

(* 03.03c: the roof's party bar until the stick was held 3 s; then the south
   boulevard's text until two A, then the party bar. [lost]: no scene. *)
let off_the_roof ?(lost = false) c =
  match C.stick_reached c 3000 with
  | Some w when not lost -> (
      match C.nth_after c Wire.A ~after:w 1 with
      | None -> text c
      | Some _ -> party c)
  | _ -> party c

(* 03.04: the party bar; the nurse's A prompt once the stick was held 3.9 s
   (the legs run), until A; the Pokedex app and the talks until three B, then
   the party bar. [lost]: no nurse's prompt. *)
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

(* 03.06: the party bar while the run is held (15 s of walk is 9.1 s with
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

let outcome checkpoint screen =
  let c = C.create () in
  reloaded := false;
  let steps = C.steps c screen in
  let reload () =
    reloaded := true;
    c.now <- c.now +. 30_000.0;
    Ok ()
  in
  let game =
    Plza_autostory.Story_game.make steps ~checkpoint_id:checkpoint ~reload
  in
  let result = Runner.run game (plan checkpoint).checkpoint in
  ((match result with Ok () -> "passed" | Error f -> Failure.to_string f), c)

let result checkpoint screen () = fst (outcome checkpoint screen)

(* Whether [part] is in [line]. *)
let contains part line =
  let n = String.length part in
  let rec at i =
    i + n <= String.length line && (String.sub line i n = part || at (i + 1))
  in
  at 0

(* The arch where 03.02b ends: free control with the minimap 03.03 starts
   on. *)
let at_arch c = { (party c) with minimap = Some "03.03-start" }

(* The start check of [checkpoint]'s plan on [screen], with its log lines. *)
let start_check ?execution checkpoint screen () =
  let c = C.create () in
  let execution = Option.value execution ~default:(plan checkpoint).execution in
  let r =
    Plza_autostory.Start_signature.check (C.steps c screen)
      ~checkpoint_id:checkpoint execution
  in
  String.concat "\n"
    ((match r with
     | Ok () -> "ok"
     | Error e -> Engine_run.Failure.cause_to_string e)
    :: C.lines c)

(* The run's skips, its moves and its end. *)
let skips checkpoint screen =
  let r, c = outcome checkpoint screen in
  let kept line =
    contains ": skipped (" line
    || String.starts_with ~prefix:"[PLZA] story_battle: Picking" line
    || line = "[Story] " ^ checkpoint ^ ": done"
  in
  String.concat "\n" (r :: List.filter kept (C.lines c))

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
  String.concat "\n" (List.rev !sent)

(* [checkpoint] run with Story_game.run_watched: what the page showed. *)
let watched checkpoint screen () =
  page (fun () ->
      let c = C.create () in
      reloaded := false;
      let game =
        Plza_autostory.Story_game.make (C.steps c screen)
          ~checkpoint_id:checkpoint ~reload:(fun () -> Ok ())
      in
      let report = Plan_watch.create (plan checkpoint).checkpoint in
      ignore
        (Plza_autostory.Story_game.run_watched ~mode:"testing" report game
           (plan checkpoint).checkpoint))

let cases =
  [
    case "01.00b: Confirm Choices, Ready!, the opening skipped, the platform"
      (result "01.00b" new_game) "passed";
    case "01.00b on another screen: nothing pressed, repeats"
      (result "01.00b" (new_game ~confirm:false))
      "01.00b event 1 (confirm): not_on_confirm_choices: 01.00b starts on the \
       new game's \"Confirm Choices\" screen, after the language, look and \
       name (made by hand). It is not on screen; nothing was pressed.";
    case "01.01: the platform to the controls hint after the arrival scenes"
      (result "01.01" platform) "passed";
    case "01.01 lost: the walk's white fade never shows"
      (result "01.01" (platform ~lost:true))
      "01.01 event 3 (platform_to_plaza): walk_no_end: platform_to_plaza: no \
       end event within 11287 ms of the last leg";
    case "01.01 with the hint faded: a reload, then the whole checkpoint"
      (fun () ->
        let r = result "01.01" (platform ~faded:true) () in
        Printf.sprintf "%s, reloaded %b" r !reloaded)
      "passed, reloaded true";
    case "01.01 off the platform: no controls hint, even after a reload"
      (result "01.01" look)
      "01.01 event 1 (on_platform): platform_not_seen: No controls hint on 2 \
       looks in a row within 10000 ms.";
    case "01.00b on the watch page: its events move, its run passes"
      (watched "01.00b" new_game)
      "plan 01.00b: confirm=pending opening=pending\n\
       run testing 01.00b=current\n\
       plan 01.00b: confirm=current opening=pending\n\
       plan 01.00b: confirm=done opening=pending\n\
       plan 01.00b: confirm=done opening=current\n\
       plan 01.00b: confirm=done opening=done\n\
       run testing 01.00b=passed";
    case "01.01 lost on the watch page: the walk fails with its reason"
      (fun () ->
        let shown =
          String.split_on_char '\n' (watched "01.01" (platform ~lost:true) ())
        in
        String.concat "\n" (List.filteri (fun i _ -> i >= 6) shown))
      "plan 01.01: on_platform=done text_speed_fast=done \
       platform_to_plaza=current arrival_to_ad=pending skip_ad=pending \
       arrival_scenes=pending\n\
       plan 01.01: on_platform=done text_speed_fast=done \
       platform_to_plaza=failed(walk_no_end: platform_to_plaza: no end event \
       within 11287 ms of the last leg) arrival_to_ad=pending skip_ad=pending \
       arrival_scenes=pending\n\
       run testing 01.01=failed";
    case "01.02: the chase, Pancham's scene to its choice, row 1, Ryon's prompt"
      (fun () ->
        let r, c = outcome "01.02" pancham in
        String.concat "\n"
          (r
          :: List.filter
               (fun line ->
                 String.starts_with ~prefix:"[PLZA] choose" line
                 || String.starts_with ~prefix:"[PLZA scene] done" line)
               (C.lines c)))
      "passed\n\
       [PLZA scene] done on choice.\n\
       [PLZA] choose_1: row 0 of 2 highlighted\n\
       [PLZA scene] done on control.";
    case "01.02 lost: no scene after the chase, Ryon's prompt alone"
      (result "01.02" (pancham ~lost:true))
      "01.02 event 2 (pancham_cornered): scene_ended_in_control: scene: the \
       scene ended in control, the party bar up 5000 ms with nothing busy \
       (expecting the choice box, the controls hint).";
    case "01.03: to Chikorita's prompt, through the cards, Andi beaten"
      (fun () ->
        let r, c = outcome "01.03" starter in
        String.concat "\n"
          (r
          :: List.filter
               (fun line ->
                 List.exists
                   (fun prefix -> String.starts_with ~prefix line)
                   [
                     "[PLZA] approach_starter";
                     "[PLZA] story_battle";
                     "[PLZA scene] done";
                   ])
               (C.lines c)))
      "passed\n\
       [PLZA] approach_starter: the A prompt held 1000 ms with nothing busy: \
       control.\n\
       [PLZA] approach_starter: A on the A prompt after 600 ms of the last leg \
       started a talk.\n\
       [PLZA] approach_starter: started on: dialog_box, advance_arrow\n\
       [PLZA scene] done on battle.\n\
       [PLZA] story_battle: Move Effectiveness: Top: Effective; Left: Super \
       Effective; Right: (Unable to Detect); Bottom: No Effect;\n\
       [PLZA] story_battle: Picking Move: Left\n\
       [PLZA] story_battle: a dialogue box after the attacks: the battle is \
       over.\n\
       [PLZA scene] done on control.";
    case "01.03 no symbols: ZL never locks on in the battle"
      (result "01.03" (starter ~no_symbols:true))
      "01.03 event 3 (andi_battle): battle_failed: fight_story_battle(): no \
       dialogue after the battle within the timeout.";
    case "01.03 resumed inside Andi's battle: the walk and the scene skipped"
      (fun () -> skips "01.03" (in_battle ~after:0.0))
      "passed\n\
       [Story] 01.03 #1 approach_starter: skipped (talk_or_battle_shows)\n\
       [Story] 01.03 #2 andi_battle_start: skipped (battle_shows)\n\
       [PLZA] story_battle: Picking Move: Left\n\
       [Story] 01.03: done";
    case
      "01.03 resumed at Urbain's heal: the walk skipped, the scene to the HUD"
      (fun () -> skips "01.03" rematch)
      "passed\n\
       [Story] 01.03 #1 approach_starter: skipped (talk_or_battle_shows)\n\
       [PLZA] story_battle: Picking Move: Left\n\
       [Story] 01.03: done";
    case "01.03 resumed in the alley after it: every event skipped"
      (fun () -> skips "01.03" party)
      "passed\n\
       [Story] 01.03 #1 approach_starter: skipped (party_bar_free)\n\
       [Story] 01.03 #2 andi_battle_start: skipped (party_bar_free)\n\
       [Story] 01.03 #3 andi_battle: skipped (party_bar_free)\n\
       [Story] 01.03 #4 after_andi: skipped (party_bar_free)\n\
       [Story] 01.03: done";
    case
      "02.01: the Battle Zone walk, Brigitte's talk, Cleffa beaten, the plaza"
      (fun () ->
        let r, c = outcome "02.01" brigitte in
        String.concat "\n"
          (r
          :: List.filter
               (fun line ->
                 List.exists
                   (fun prefix -> String.starts_with ~prefix line)
                   [
                     "[PLZA] battle_zone_to_brigitte";
                     "[PLZA] story_battle: Picking";
                     "[PLZA scene] done";
                   ])
               (C.lines c)))
      "passed\n\
       [PLZA] battle_zone_to_brigitte: legs done, screen now: dialog_box, \
       advance_arrow\n\
       [PLZA scene] done on battle.\n\
       [PLZA] story_battle: Picking Move: Left\n\
       [PLZA scene] done on control.";
    case "02.01 lost: no Brigitte after the walk, the party bar alone"
      (result "02.01" party)
      "02.01 event 2 (brigitte_battle_start): scene_ended_in_control: scene: \
       the scene ended in control, the party bar up 5000 ms with nothing busy \
       (expecting the battle HUD, the controls hint).";
    case "02.01 with no scene after the battle: the start window passes"
      (result "02.01" (brigitte ~no_scene:true))
      "02.01 event 4 (after_brigitte): scene_never_started: scene: the scene \
       never started (player not at its trigger?): the HUD up and no text, \
       choice, battle or cutscene for 45000 ms (expecting the controls hint, \
       the party bar or the A prompt).";
    case "02.02: the street's cutscene skipped, the gate, Taunie, Hotel Z"
      (fun () ->
        let r, c = outcome "02.02" hotel_z in
        String.concat "\n"
          (r
          :: List.filter
               (fun line ->
                 List.exists
                   (fun prefix -> String.starts_with ~prefix line)
                   [
                     "[PLZA] to_";
                     "[PLZA] through_";
                     "[PLZA] plus";
                     "[PLZA scene] done";
                   ])
               (C.lines c)))
      "passed\n\
       [PLZA] to_blocked_street: the end event after 750 ms of the last leg.\n\
       [PLZA] to_blocked_street: ended on: fade_black\n\
       [PLZA] plus_skip: a black fade 0 ms after the hold.\n\
       [PLZA scene] done on control.\n\
       [PLZA] to_battle_zone_gate: A on the A prompt after 3000 ms of the last \
       leg started a talk.\n\
       [PLZA] to_battle_zone_gate: started on: dialog_box, advance_arrow\n\
       [PLZA scene] done on control.\n\
       [PLZA] through_covered_passage: legs done, screen now: dialog_box, \
       advance_arrow\n\
       [PLZA scene] done on control.";
    case "02.02 lost: no black fade into the street"
      (result "02.02" (hotel_z ~lost:true))
      "02.02 event 1 (to_blocked_street): walk_no_end: to_blocked_street: no \
       end event within 3363 ms of the last leg";
    case "02.03: up the steps to the door's prompt, A Enter, the lobby"
      (fun () ->
        let r, c = outcome "02.03" lobby in
        String.concat "\n"
          (r
          :: List.filter
               (fun line ->
                 List.exists
                   (fun prefix -> String.starts_with ~prefix line)
                   [ "[PLZA] to_"; "[PLZA] press"; "[PLZA scene] done" ])
               (C.lines c)))
      "passed\n\
       [PLZA] to_hotel_z_door: the end event after 2000 ms of the last leg, \
       before its 3375 ms: passed on the way, on.\n\
       [PLZA] to_hotel_z_door: the end event after 2250 ms of the last leg, \
       before its 3375 ms: passed on the way, on.\n\
       [PLZA] to_hotel_z_door: the end event after 2500 ms of the last leg, \
       before its 3375 ms: passed on the way, on.\n\
       [PLZA] to_hotel_z_door: the end event after 2750 ms of the last leg, \
       before its 3375 ms: passed on the way, on.\n\
       [PLZA] to_hotel_z_door: the end event after 3000 ms of the last leg, \
       before its 3375 ms: passed on the way, on.\n\
       [PLZA] to_hotel_z_door: the end event after 3250 ms of the last leg, \
       before its 3375 ms: passed on the way, on.\n\
       [PLZA] to_hotel_z_door: the end event after 3500 ms of the last leg.\n\
       [PLZA] to_hotel_z_door: ended on: player_can_move, interact_prompt\n\
       [PLZA scene] done on control.";
    case "02.03 lost: no door prompt"
      (result "02.03" (lobby ~lost:true))
      "02.03 event 1 (to_hotel_z_door): walk_no_end: to_hotel_z_door: no end \
       event within 5061 ms of the last leg";
    case "02.04: along the counter, the clerk's prompt, check-in"
      (fun () ->
        let r, c = outcome "02.04" clerk in
        String.concat "\n"
          (r
          :: List.filter
               (fun line ->
                 List.exists
                   (fun prefix -> String.starts_with ~prefix line)
                   [ "[PLZA] to_"; "[PLZA] press"; "[PLZA scene] done" ])
               (C.lines c)))
      "passed\n\
       [PLZA] to_front_counter: A on the A prompt after 0 ms of the last leg \
       started a talk.\n\
       [PLZA] to_front_counter: started on: dialog_box, advance_arrow\n\
       [PLZA scene] done on control.";
    case "02.04 lost: no clerk's prompt"
      (result "02.04" (clerk ~lost:true))
      "02.04 event 1 (to_front_counter): walk_no_end: to_front_counter: no \
       talk started within 1000 ms after the last leg";
    case "02.05: the elevator, 2F, Room 202"
      (fun () ->
        let r, c = outcome "02.05" elevator in
        String.concat "\n"
          (r
          :: List.filter
               (fun line ->
                 List.exists
                   (fun prefix -> String.starts_with ~prefix line)
                   [ "[PLZA] to_"; "[PLZA] choose"; "[PLZA scene] done" ])
               (C.lines c)))
      "passed\n\
       [PLZA] to_lobby_elevator: the end event after 2000 ms of the last leg.\n\
       [PLZA] to_lobby_elevator: ended on: player_can_move, interact_prompt\n\
       [PLZA scene] done on choice.\n\
       [PLZA] choose_0: row 0 of 2 highlighted\n\
       [PLZA scene] done on control.\n\
       [PLZA] to_room_202: the end event after 2000 ms of the last leg.\n\
       [PLZA] to_room_202: ended on: player_can_move, interact_prompt\n\
       [PLZA scene] done on control.";
    case "02.05 lost: no elevator prompt"
      (result "02.05" (elevator ~lost:true))
      "02.05 event 1 (to_lobby_elevator): walk_no_end: to_lobby_elevator: no \
       end event within 3363 ms of the last leg";
    case "02.06: a prompt passed, the bed, rest until morning"
      (fun () ->
        let r, c = outcome "02.06" bed in
        String.concat "\n"
          (r
          :: List.filter
               (fun line ->
                 List.exists
                   (fun prefix -> String.starts_with ~prefix line)
                   [ "[PLZA] to_"; "[PLZA] choose"; "[PLZA scene] done" ])
               (C.lines c)))
      "passed\n\
       [PLZA] to_bed: the end event after 500 ms of the last leg, before its \
       750 ms: passed on the way, on.\n\
       [PLZA] to_bed: the end event after 1000 ms of the last leg.\n\
       [PLZA] to_bed: ended on: player_can_move, interact_prompt\n\
       [PLZA scene] done on choice.\n\
       [PLZA] choose_0: row 0 of 2 highlighted\n\
       [PLZA scene] done on control.";
    case "02.06 lost: no bed prompt"
      (result "02.06" (bed ~lost:true))
      "02.06 event 1 (to_bed): walk_no_end: to_bed: no end event within 1665 \
       ms of the last leg";
    case "02.07: to the door's prompt, A Leave, the first evening"
      (fun () ->
        let r, c = outcome "02.07" room_door in
        String.concat "\n"
          (r
          :: List.filter
               (fun line ->
                 List.exists
                   (fun prefix -> String.starts_with ~prefix line)
                   [ "[PLZA] to_"; "[PLZA scene] done" ])
               (C.lines c)))
      "passed\n\
       [PLZA] to_room_door: the end event after 1750 ms of the last leg.\n\
       [PLZA] to_room_door: ended on: player_can_move, interact_prompt\n\
       [PLZA scene] done on control.";
    case "02.07 lost: no door prompt"
      (result "02.07" (room_door ~lost:true))
      "02.07 event 1 (to_room_door): walk_no_end: to_room_door: no end event \
       within 2231 ms of the last leg";
    case "03.01: out of Room 202, the elevator, the lobby"
      (fun () ->
        let r, c = outcome "03.01" out_of_room in
        String.concat "\n"
          (r
          :: List.filter
               (fun line ->
                 List.exists
                   (fun prefix -> String.starts_with ~prefix line)
                   [
                     "[PLZA] to_";
                     "[PLZA] out";
                     "[PLZA] choose";
                     "[PLZA scene] done";
                   ])
               (C.lines c)))
      "passed\n\
       [PLZA] out_of_room_202: the end event after 1000 ms of the last leg.\n\
       [PLZA] out_of_room_202: ended on: player_can_move, interact_prompt\n\
       [PLZA scene] done on control.\n\
       [PLZA] to_2f_elevator: the end event after 2000 ms of the last leg.\n\
       [PLZA] to_2f_elevator: ended on: player_can_move, interact_prompt\n\
       [PLZA scene] done on choice.\n\
       [PLZA] choose_0: row 0 of 2 highlighted\n\
       [PLZA scene] done on control.";
    case "03.01 lost: no door prompt"
      (result "03.01" (out_of_room ~lost:true))
      "03.01 event 1 (out_of_room_202): walk_no_end: out_of_room_202: no end \
       event within 1099 ms of the last leg";
    case "03.02: across the lobby, A Leave, the Main Menu card"
      (fun () ->
        let r, c = outcome "03.02" hotel_door in
        String.concat "\n"
          (r
          :: List.filter
               (fun line ->
                 List.exists
                   (fun prefix -> String.starts_with ~prefix line)
                   [ "[PLZA] to_"; "[PLZA] press"; "[PLZA scene] done" ])
               (C.lines c)))
      "passed\n\
       [PLZA] to_hotel_front_door: legs done, screen now: player_can_move, \
       interact_prompt\n\
       [PLZA scene] done on control.";
    case "03.02 lost: no front door prompt"
      (result "03.02" (hotel_door ~lost:true))
      "03.02 event 2 (leave_hotel_z): prompt_not_seen: scene: no A prompt to \
       press through: free control with nothing to take A (the walk before it \
       stopped short?)";
    case "03.02b: the plaza scene, Taunie's two battles, the map talk"
      (fun () ->
        let r, c = outcome "03.02b" quartiere_verde in
        String.concat "\n"
          (r
          :: List.filter
               (fun line ->
                 List.exists
                   (fun prefix -> String.starts_with ~prefix line)
                   [
                     "[PLZA] to_";
                     "[PLZA] story_battle: Picking";
                     "[PLZA] talk_through";
                     "[PLZA scene] done";
                   ])
               (C.lines c)))
      "passed\n\
       [PLZA] to_plaza_scene_prompt: the end event after 4000 ms of the last \
       leg.\n\
       [PLZA] to_plaza_scene_prompt: ended on: player_can_move, interact_prompt\n\
       [PLZA scene] done on control.\n\
       [PLZA] to_taunie: A on the A prompt after 3000 ms of the last leg \
       started a talk.\n\
       [PLZA] to_taunie: started on: dialog_box, advance_arrow\n\
       [PLZA scene] done on battle.\n\
       [PLZA] story_battle: Picking Move: Left\n\
       [PLZA scene] done on battle.\n\
       [PLZA] story_battle: Picking Move: Left\n\
       [PLZA] talk_through_map_screen: the party bar held: back in the \
       overworld";
    case "03.02b lost: no plaza scene prompt"
      (result "03.02b" (quartiere_verde ~lost:true))
      "03.02b event 1 (to_plaza_scene_prompt): walk_no_end: \
       to_plaza_scene_prompt: no end event within 9023 ms of the last leg";
    case "03.03: Taunie runs off, the gate walk runs with B, the rock pile"
      (fun () ->
        let r, c = outcome "03.03" rock_pile in
        String.concat "\n"
          ((r ^ Printf.sprintf ", %d run" (runs c))
          :: List.filter
               (fun line ->
                 List.exists
                   (fun prefix -> String.starts_with ~prefix line)
                   [ "[PLZA] through"; "[PLZA scene] done" ])
               (C.lines c)))
      "passed, 1 run\n\
       [PLZA scene] done on control.\n\
       [PLZA] through_hotel_gate: legs done, screen now: dialog_box, \
       advance_arrow\n\
       [PLZA scene] done on control.";
    case
      "03.03 lost: no rock pile scene, yet it passes (the fork's plain scene)"
      (result "03.03" (rock_pile ~lost:true))
      "passed";
    case "03.03b: the side street, the ladder, the rooftop"
      (fun () ->
        let r, c = outcome "03.03b" ladder in
        String.concat "\n"
          (r
          :: List.filter
               (fun line ->
                 List.exists
                   (fun prefix -> String.starts_with ~prefix line)
                   [ "[PLZA] side"; "[PLZA] climb"; "[PLZA scene] done" ])
               (C.lines c)))
      "passed\n\
       [PLZA] side_street_to_wall: legs done, screen now: player_can_move\n\
       [PLZA] climb_ladder: Climb Up after 2 steps along the wall\n\
       [PLZA scene] done on control.";
    case "03.03b lost: no ladder prompt along the wall"
      (result "03.03b" (ladder ~lost:true))
      "03.03b event 2 (climb_ladder): ladder_not_found: no Climb Up prompt \
       stepping along the wall";
    case "03.03c: off the roof into the south boulevard scene"
      (fun () ->
        let r, c = outcome "03.03c" off_the_roof in
        String.concat "\n"
          (r
          :: List.filter
               (fun line ->
                 List.exists
                   (fun prefix -> String.starts_with ~prefix line)
                   [ "[PLZA] off"; "[PLZA scene] done" ])
               (C.lines c)))
      "passed\n\
       [PLZA] off_the_roof: a scene (text waiting for A) took control after \
       5250 ms of the last leg: the walk stops.\n\
       [PLZA scene] done on control.";
    case "03.03c lost: no scene takes the walk"
      (result "03.03c" (off_the_roof ~lost:true))
      "03.03c event 1 (off_the_roof): walk_no_scene: off_the_roof: control \
       still free after 8162 ms of the last leg: no scene took it";
    case "03.04: into the Pokemon Center, the nurse, the Pokedex with B"
      (fun () ->
        let r, c = outcome "03.04" nurse in
        String.concat "\n"
          (r
          :: List.filter
               (fun line ->
                 List.exists
                   (fun prefix -> String.starts_with ~prefix line)
                   [ "[PLZA] into"; "[PLZA scene] done" ])
               (C.lines c)))
      "passed\n\
       [PLZA] into_pokemon_center: A on the A prompt after 750 ms of the last \
       leg started a talk.\n\
       [PLZA] into_pokemon_center: started on: dialog_box, advance_arrow\n\
       [PLZA scene] done on control.";
    case "03.04 lost: no nurse's prompt"
      (result "03.04" (nurse ~lost:true))
      "03.04 event 1 (into_pokemon_center): walk_no_end: into_pokemon_center: \
       no talk started within 1000 ms after the last leg";
    case "03.02b resumed at the arch after it: every event skipped"
      (fun () -> skips "03.02b" at_arch)
      "passed\n\
       [Story] 03.02b #1 to_plaza_scene_prompt: skipped (minimap:03.03-start)\n\
       [Story] 03.02b #2 plaza_scene: skipped (minimap:03.03-start)\n\
       [Story] 03.02b #3 to_taunie: skipped (minimap:03.03-start)\n\
       [Story] 03.02b #4 taunie_battle_start: skipped (minimap:03.03-start)\n\
       [Story] 03.02b #5 battle_totodile: skipped (minimap:03.03-start)\n\
       [Story] 03.02b #6 tepig_battle_start: skipped (minimap:03.03-start)\n\
       [Story] 03.02b #7 battle_tepig: skipped (minimap:03.03-start)\n\
       [Story] 03.02b #8 after_taunie_battle: skipped (minimap:03.03-start)\n\
       [Story] 03.02b: done";
    case "03.02b's start: the plaza, no minimap, nothing skipped"
      (fun () ->
        String.concat "\n"
          (List.filter
             (fun line -> contains "skipped" line)
             (C.lines (snd (outcome "03.02b" quartiere_verde)))))
      "";
    case "03.03's start check at the arch: the minimap reads 03.03-start"
      (start_check "03.03" at_arch)
      "ok\n\
       [Checkpoint] 03.03: START CHECKED: the screen reads (minimap \
       03.03-start), its start is (minimap 03.03-start)";
    case "03.03's start check elsewhere: chain_off_start"
      (start_check "03.03" party)
      "chain_off_start: the run is not at 03.03's start: the screen reads (no \
       minimap), its start is (minimap 03.03-start)\n\
       [Checkpoint] 03.03: START CHECK FAILED: the screen reads (no minimap), \
       its start is (minimap 03.03-start)";
    case "03.04's start check at the arch: chain_off_start, the wrong minimap"
      (start_check "03.04" at_arch)
      "chain_off_start: the run is not at 03.04's start: the screen reads \
       (minimap 03.03-start), its start is (minimap 03.04-start)\n\
       [Checkpoint] 03.04: START CHECK FAILED: the screen reads (minimap \
       03.03-start), its start is (minimap 03.04-start)";
    case "03.02's start: no signature, unchecked"
      (start_check "03.02" party)
      "ok\n\
       [Checkpoint] 03.02: START UNCHECKED: its plan names no start signature";
    case "a start signature naming the party: refused, nothing reads it"
      (start_check
         ~execution:[ ("start_signature", `Assoc [ ("party", `Int 1) ]) ]
         "03.03" at_arch)
      "start_signature_unread: 03.03: its start signature is not one minimap \
       ({\"minimap\": \"<name>\"}): only the minimap is read here";
    case "a start signature naming an unrecorded minimap: refused"
      (start_check
         ~execution:
           [
             ("start_signature", `Assoc [ ("minimap", `String "03.05-start") ]);
           ]
         "03.03" at_arch)
      "start_signature_unread: 03.03: its start signature names minimap \
       03.05-start, which is not recorded";
    case "03.06: on to Wild Zone 1's gate, Taunie, the Wild Zones card"
      (fun () ->
        let r, c = outcome "03.06" wild_zones_card in
        String.concat "\n"
          ((r ^ Printf.sprintf ", %d run" (runs c))
          :: List.filter
               (fun line ->
                 List.exists
                   (fun prefix -> String.starts_with ~prefix line)
                   [ "[PLZA] center"; "[PLZA scene] done" ])
               (C.lines c)))
      "passed, 1 run\n\
       [PLZA] center_to_zone_1: legs done, screen now: dialog_box, advance_arrow\n\
       [PLZA scene] done on control.";
    case "03.06 lost: no scene within the start window"
      (result "03.06" (wild_zones_card ~lost:true))
      "03.06 event 2 (wild_zones_tutorial): scene_never_started: scene: the \
       scene never started (player not at its trigger?): the HUD up and no \
       text, choice, battle or cutscene for 45000 ms (expecting the controls \
       hint, the party bar or the A prompt).";
    case "03.06's start check outside the Center"
      (start_check "03.06" (fun c ->
           { (party c) with minimap = Some "03.06-start" }))
      "ok\n\
       [Checkpoint] 03.06: START CHECKED: the screen reads (minimap \
       03.06-start), its start is (minimap 03.06-start)";
    case "the walk is walked before 03.03, run after"
      (fun () ->
        Printf.sprintf "%b %b"
          (Plza_autostory.Story_game.walk_only "01.01")
          (Plza_autostory.Story_game.walk_only "03.03"))
      "true false";
  ]

let () = Table_test.run "plza_story_game" cases
