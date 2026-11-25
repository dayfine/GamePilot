open Plza_story
module Failure = Engine_run.Failure
module Game = Plza_engine.Game
module Plan = Plza_engine.Plan

let run_from = "03.03"
let walk_only id = String.compare id run_from < 0
let wait_for_platform_ms = 180_000
let opening_to_platform_ms = 240_000

let bad_args (event : Plan.event) detail =
  Error (Failure.cause ~repeats:true "bad_args" (event.id ^ ": " ^ detail))

(* An action that takes no args. *)
let no_args run steps (event : Plan.event) (args : Json_field.obj) =
  match args with
  | [] -> run steps
  | (key, _) :: _ -> bad_args event (key ^ " is not an arg of this action")

(* An action with an optional "timeout_ms". *)
let timed run ~default steps (event : Plan.event) (args : Json_field.obj) =
  match args with
  | [] -> run steps ~timeout_ms:default
  | [ ("timeout_ms", `Int ms) ] -> run steps ~timeout_ms:ms
  | _ -> bad_args event "the only arg is timeout_ms, a whole number of ms"

(* The platform's hint fades after a few seconds idle: a start that does not
   see it reloads the latest autosave, where it shows fresh, and looks again. *)
let platform_or_reload ~reload steps ~timeout_ms =
  match Platform_wait.wait_for_platform steps ~timeout_ms with
  | Error { code = "platform_not_seen"; _ } ->
      steps.Steps.log
        "[PLZA] platform wait: no controls hint (it fades when idle); \
         reloading the latest autosave to see it fresh";
      Result.bind (reload ()) (fun () ->
          Platform_wait.wait_for_platform steps ~timeout_ms)
  | outcome -> outcome

(* The story's own actions, 01.00b's and 01.01's so far. *)
let story_actions ~reload =
  [
    ("confirm_new_game", no_args New_game_confirm.run);
    ( "opening_to_platform",
      timed Platform_wait.opening_to_platform ~default:opening_to_platform_ms );
    ( "wait_for_platform",
      timed (platform_or_reload ~reload) ~default:wait_for_platform_ms );
    ("set_text_speed_fast", no_args Text_speed.run);
    ("plus_skip", no_args Plus_skip.run);
  ]

let game_actions ~reload steps =
  List.map (fun (name, action) -> (name, action steps)) (story_actions ~reload)

let scene steps (event : Plan.event) =
  let run = Scene_machine.run steps "scene" in
  match event.way with
  | None -> run Scene_machine.default
  | Some "end_on_black_fade" ->
      run { Scene_machine.default with end_on_black_fade = true }
  | Some "button_b" -> run { Scene_machine.default with button = B }
  | Some way ->
      bad_args event
        ("a scene's action is end_on_black_fade or button_b, not " ^ way)

let builtin steps (event : Plan.event) =
  match event.kind with
  | Scene -> scene steps event
  | _ ->
      Error
        (Failure.cause ~repeats:true "no_handler"
           (event.id ^ ": PLZA runs no talk, answer or save event"))

let walk steps ~checkpoint_id (event : Plan.event) (own : Plza_rules.Action.t) =
  let walk_steps = Steps.walk_game_steps steps in
  let walk_only = walk_only checkpoint_id in
  match own with
  | Walk args ->
      Plza_walk.Walk.run_event walk_steps ~walk_only ~battle_ahead:false
        event.id args

let no_save () =
  Error (Failure.cause ~repeats:true "no_save" "PLZA saves by autosave only")

let make steps ~(checkpoint : Plan.checkpoint) ~reload : Game.t =
  let checkpoint_id = checkpoint.checkpoint_id in
  {
    run_own = walk steps ~checkpoint_id;
    run_builtin = builtin steps;
    game_actions = game_actions ~reload steps;
    flag_holds = (fun _ -> false);
    position = (fun () -> None);
    between_rounds = (fun () -> Ok ());
    save = no_save;
    reload;
    log = steps.log;
  }

(* The end check's failure, after the last event, as the engine's own end
   check names one. *)
let at_end (checkpoint : Plza_engine.Plan.checkpoint) cause =
  {
    Plza_engine.Failure.checkpoint_id = checkpoint.checkpoint_id;
    event_index = List.length checkpoint.events;
    event_id = "end";
    reason = Handler cause;
  }

let run_watched ?(end_check = fun () -> Ok ()) ~mode report game checkpoint =
  Plza_engine.Plan_watch.run ~mode report (fun ~on_event ->
      Result.bind (Plza_engine.Runner.run ~on_event game checkpoint) (fun () ->
          Result.map_error (at_end checkpoint) (end_check ())))
