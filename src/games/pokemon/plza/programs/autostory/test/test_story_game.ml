(* The skeleton's 01.01 runs through the engine (Plza_engine.Runner) with
   Story_game's handlers on a scripted console: the plan decodes, its walk
   reaches the walk's handler and passes on the white fade, or fails when the
   fade never shows (lost); an event PLZA has no handler for yet fails. And
   what the watch page is sent (Story_game.run_watched): the plan at each
   event's change and the run. *)

open Plza_engine
module S = Plza_walk.Walk_screen

let case name input expectation = { Table_test.name; input; expectation }

let plan_of_file id =
  match
    Plan_decode.decode ~source:(id ^ ".plan.json")
      (Yojson.Safe.from_file (Filename.concat "../plans" (id ^ ".plan.json")))
  with
  | Ok p -> p
  | Error e -> failwith e

let plan_of_text text =
  match
    Plan_decode.decode ~source:"test.plan.json" (Yojson.Safe.from_string text)
  with
  | Ok p -> p
  | Error e -> failwith e

(* A scripted console: a clock moved by each input's time and 50 ms per read,
   and the screen as a function of it. *)
let read_ms = 50

let duration : Wire.command -> int = function
  | Press { hold_ms; cooldown_ms; _ } -> hold_ms + cooldown_ms
  | Wait { wait_ms } -> wait_ms

let scripted screen =
  let now = ref 0.0 and lines = ref [] in
  let say line = lines := line :: !lines in
  let steps : Plza_walk.Walk.game_steps =
    {
      submit = (fun c -> now := !now +. float_of_int (duration c));
      read_screen =
        (fun () ->
          now := !now +. float_of_int read_ms;
          screen !now);
      log = say;
      log_detail = say;
    }
  in
  (steps, fun () -> List.rev !lines)

(* The platform's controls hint until [fade_at] ms, then a white fade
   (never when [lost]). *)
let fade_at = 9000.0

let platform ?(lost = false) at_ms : S.t =
  let screen = S.empty ~at_ms in
  if (not lost) && at_ms >= fade_at then { screen with fade_white = true }
  else { screen with controls_hint = true }

let game steps checkpoint =
  Plza_autostory.Story_game.make steps ~checkpoint ~reload:(fun () -> Ok ())

let result screen (plan : Plan.t) () =
  let steps, _ = scripted screen in
  match Runner.run (game steps plan.checkpoint) plan.checkpoint with
  | Ok () -> "passed"
  | Error f -> Failure.to_string f

let platform_plan () = plan_of_file "01.01"

(* A plan with a scene after the walk: no handler for it yet. *)
let with_scene () =
  plan_of_text
    {|{"format": "gamepilot-checkpoint/1", "game": "plza", "execution": {},
       "checkpoint": {"id": "01.01", "title": "t",
         "start": {"place": "LumioseCity"},
         "events": [
           {"id": "w", "kind": "walk", "args": {"legs": [[0, 1000]]}},
           {"id": "arrival", "kind": "scene"}]}}|}

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

(* 01.01 run with Story_game.run_watched: what the page showed. *)
let watched screen () =
  page (fun () ->
      let plan = platform_plan () in
      let steps, _ = scripted screen in
      let report = Plan_watch.create plan.checkpoint in
      ignore
        (Plza_autostory.Story_game.run_watched ~mode:"testing" report
           (game steps plan.checkpoint)
           plan.checkpoint))

let cases =
  [
    case "01.01's plan: a zone start and its walk"
      (fun () -> Plan_text.outline (platform_plan ()))
      "plza 01.01 from LumioseCity: 1 walk";
    case "01.01: off the platform, walked to the white fade"
      (fun () -> result platform (platform_plan ()) ())
      "passed";
    case "01.01 lost: the walk's white fade never shows"
      (fun () -> result (platform ~lost:true) (platform_plan ()) ())
      "01.01 event 1 (platform_to_plaza): walk_no_end: platform_to_plaza: no \
       end event within 11950 ms of the last leg";
    case "a scene: no handler in the skeleton yet"
      (fun () -> result platform (with_scene ()) ())
      "01.01 event 2 (arrival): no_handler: arrival: PLZA runs no talk, answer \
       or save event";
    case "01.01 on the watch page: its walk moves, its run passes"
      (watched platform)
      "plan 01.01: platform_to_plaza=pending\n\
       run testing 01.01=current\n\
       plan 01.01: platform_to_plaza=current\n\
       plan 01.01: platform_to_plaza=done\n\
       run testing 01.01=passed";
    case "01.01 lost on the watch page: the walk fails with its reason"
      (watched (platform ~lost:true))
      "plan 01.01: platform_to_plaza=pending\n\
       run testing 01.01=current\n\
       plan 01.01: platform_to_plaza=current\n\
       plan 01.01: platform_to_plaza=failed(walk_no_end: platform_to_plaza: no \
       end event within 11950 ms of the last leg)\n\
       run testing 01.01=failed";
  ]

let () = Table_test.run "plza_story_game" cases
