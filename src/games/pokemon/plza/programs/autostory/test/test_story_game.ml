(* 01.00b and 01.01 run through the engine (Plza_checkpoints.Runner) with
   Story_game's handlers on a scripted console (Fake_console): the plans
   decode, every event reaches its handler, and each handler's presses move a
   game that answers them as the console did. Also the failures: a walk whose
   white fade never shows (lost), a start that is not Confirm Choices, a
   platform never seen. *)

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
let platform ?(lost = false) c =
  match C.nth_after c Wire.X ~after:0.0 0 with
  | None -> hint c
  | Some x when C.nth_after c Wire.B ~after:x 0 = None -> look c
  | Some _ -> (
      match (lost, C.stick_reached c 8000) with
      | false, Some w -> arrival c w
      | _ -> hint c)

let outcome checkpoint screen =
  let c = C.create () in
  let steps = C.steps c screen in
  let game =
    Plza_autostory.Story_game.make steps ~checkpoint_id:checkpoint
      ~reload:(fun () -> Ok ())
  in
  let result = Runner.run game (plan checkpoint).checkpoint in
  ((match result with Ok () -> "passed" | Error f -> Failure.to_string f), c)

let result checkpoint screen () = fst (outcome checkpoint screen)

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
    case "01.01 off the platform: no controls hint" (result "01.01" look)
      "01.01 event 1 (on_platform): platform_not_seen: No controls hint on 2 \
       looks in a row within 10000 ms.";
    case "the walk is walked before 03.03, run after"
      (fun () ->
        Printf.sprintf "%b %b"
          (Plza_autostory.Story_game.walk_only "01.01")
          (Plza_autostory.Story_game.walk_only "03.03"))
      "true false";
  ]

let () = Table_test.run "plza_story_game" cases
