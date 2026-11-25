(* 01.00b and 01.01 run through the engine (Plza_checkpoints.Runner) with
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
    case "the walk is walked before 03.03, run after"
      (fun () ->
        Printf.sprintf "%b %b"
          (Plza_autostory.Story_game.walk_only "01.01")
          (Plza_autostory.Story_game.walk_only "03.03"))
      "true false";
  ]

let () = Table_test.run "plza_story_game" cases
