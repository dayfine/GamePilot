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

(* A scene, as the fork's action table runs one: with a story battle ahead,
   the battle HUD ends it and the run goes on there (but for a battle's
   start). *)
let run_scene ~jump steps (event : Plan.event) (config : Scene_machine.config) =
  Scene_machine.run steps "scene"
    {
      config with
      end_at_battle =
        (not config.stop_at_battle) && Battle_jump.battle_ahead jump event;
    }

(* A scene stopping at a choice, as the fork's: its "button" A or B (A when
   absent). *)
let scene_to_choice ~jump steps (event : Plan.event) (args : Json_field.obj) =
  let to_choice button =
    run_scene ~jump steps event
      { Scene_machine.default with stop_at_choice = true; button }
  in
  match args with
  | [] | [ ("button", `String "A") ] -> to_choice Wire.A
  | [ ("button", `String "B") ] -> to_choice Wire.B
  | _ -> bad_args event "the only arg is button, \"A\" or \"B\""

(* A scene to a battle's start, as the fork's: to the battle HUD. *)
let scene_to_battle steps =
  Scene_machine.run steps "scene"
    { Scene_machine.default with stop_at_battle = true }

(* The story's own actions, 01.00b's to 01.03's so far. *)
let story_actions ~reload ~jump =
  [
    ("confirm_new_game", no_args New_game_confirm.run);
    ( "opening_to_platform",
      timed Platform_wait.opening_to_platform ~default:opening_to_platform_ms );
    ( "wait_for_platform",
      timed (platform_or_reload ~reload) ~default:wait_for_platform_ms );
    ("set_text_speed_fast", no_args Text_speed.run);
    ("plus_skip", no_args Plus_skip.run);
    ("scene_to_choice", scene_to_choice ~jump);
    ("choose_1", no_args (fun steps -> Choose_row.run steps 1));
    ("scene_to_battle", no_args scene_to_battle);
    ("story_battle", no_args Battle.run);
  ]

let game_actions ~reload ~jump steps =
  List.map
    (fun (name, action) -> (name, action steps))
    (story_actions ~reload ~jump)

let scene ~jump steps (event : Plan.event) =
  let run = run_scene ~jump steps event in
  match event.way with
  | None -> run Scene_machine.default
  | Some "end_on_black_fade" ->
      run { Scene_machine.default with end_on_black_fade = true }
  | Some "button_b" -> run { Scene_machine.default with button = B }
  | Some way ->
      bad_args event
        ("a scene's action is end_on_black_fade or button_b, not " ^ way)

let builtin ~jump steps (event : Plan.event) =
  match event.kind with
  | Scene -> scene ~jump steps event
  | _ ->
      Error
        (Failure.cause ~repeats:true "no_handler"
           (event.id ^ ": PLZA runs no talk, answer or save event"))

let walk steps ~checkpoint_id ~jump (event : Plan.event)
    (own : Plza_rules.Action.t) =
  let walk_steps = Steps.walk_game_steps steps in
  let walk_only = walk_only checkpoint_id in
  let battle_ahead = Battle_jump.battle_ahead jump event in
  match own with
  | Walk args ->
      Plza_walk.Walk.run_event walk_steps ~walk_only ~battle_ahead event.id args

(* Every handler runs through the jump to a story battle: one that ends on a
   battle goes on there, as the fork's engine resumes at the action its
   failure names. *)
let through jump event handle =
  Battle_jump.run jump event (fun () ->
      Battle_jump.after jump event (handle ()))

let jumping jump (name, action) =
  (name, fun event args -> through jump event (fun () -> action event args))

let own_through jump steps ~checkpoint_id event own =
  through jump event (fun () -> walk steps ~checkpoint_id ~jump event own)

let builtin_through jump steps event =
  through jump event (fun () -> builtin ~jump steps event)

let no_save () =
  Error (Failure.cause ~repeats:true "no_save" "PLZA saves by autosave only")

let make steps ~(checkpoint : Plan.checkpoint) ~reload : Game.t =
  let checkpoint_id = checkpoint.checkpoint_id in
  let jump = Battle_jump.make checkpoint ~log:steps.Steps.log in
  {
    run_own = own_through jump steps ~checkpoint_id;
    run_builtin = builtin_through jump steps;
    game_actions = List.map (jumping jump) (game_actions ~reload ~jump steps);
    flag_holds = Resume_flags.holds steps;
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
