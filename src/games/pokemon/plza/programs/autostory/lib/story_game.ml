open Plza_story
module Failure = Engine_run.Failure
module Game = Plza_checkpoints.Game
module Plan = Plza_checkpoints.Plan

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

(* A scene stopping at a choice, as the fork's: its "button" A or B (A when
   absent). *)
let scene_to_choice steps (event : Plan.event) (args : Json_field.obj) =
  let to_choice button =
    Scene_machine.run steps "scene"
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

(* A scene with a start window, as the fork's: control before any scene
   waits up to "start_window_ms" for one. *)
let scene_with_start_window steps (event : Plan.event) (args : Json_field.obj) =
  match args with
  | [ ("start_window_ms", `Int ms) ] when ms > 0 ->
      Scene_machine.run steps "scene"
        { Scene_machine.default with start_window_ms = Some ms }
  | _ ->
      bad_args event "the only arg is start_window_ms, a positive number of ms"

let talk_steps steps : Plza_walk.Talk_prompt.game_steps =
  let walk = Steps.walk_game_steps steps in
  {
    submit = walk.submit;
    read_screen = walk.read_screen;
    log = walk.log;
    log_detail = walk.log_detail;
  }

(* Free control with no A prompt, on two reads 300 ms apart: nothing for A
   to take. *)
let no_prompt_gap_ms = 300
let no_prompt (l : Look.t) = Look.control_shows l && not l.interact_prompt

let prompt_missing steps =
  no_prompt (steps.Steps.read_screen ())
  &&
  (Steps.wait steps no_prompt_gap_ms;
   no_prompt (steps.read_screen ()))

let prompt_not_seen =
  Error
    (Failure.cause "prompt_not_seen"
       "scene: no A prompt to press through: free control with nothing to take \
        A (the walk before it stopped short?)")

(* A scene that presses A first, as the fork's: A through the prompt first
   ({!Plza_walk.Talk_prompt.press_through}), then the scene; with "stop_at_choice", to the
   choice. *)
let through_prompt steps config =
  if prompt_missing steps then prompt_not_seen
  else (
    Plza_walk.Talk_prompt.press_through (talk_steps steps);
    Scene_machine.run steps "scene" config)

let scene_through_prompt steps (event : Plan.event) (args : Json_field.obj) =
  match args with
  | [] -> through_prompt steps Scene_machine.default
  | [ ("stop_at_choice", `Bool true) ] ->
      through_prompt steps { Scene_machine.default with stop_at_choice = true }
  | _ -> bad_args event "the only arg is stop_at_choice, true"

(* 01.00a's choices: "language" (a tag), "look" (1 to 8) and "name", each
   optional, the fork's default when absent. *)
let language_choice (c : New_game_choices.t) event tag =
  match New_game_choices.of_tag tag with
  | Some language -> Ok { c with language }
  | None ->
      bad_args event
        ("language is one of "
        ^ String.concat ", " New_game_choices.tags
        ^ ", not " ^ tag)

let choice (c : New_game_choices.t) (event : Plan.event) = function
  | "language", `String tag -> language_choice c event tag
  | "look", `Int look -> Ok { c with look }
  | "name", `String name -> Ok { c with name }
  | key, _ ->
      bad_args event
        (key
       ^ ": the args are language (a tag), look (a whole number) and name (a \
          string)")

let new_game run _steps (event : Plan.event) (args : Json_field.obj) =
  Result.bind
    (List.fold_left
       (fun acc arg -> Result.bind acc (fun c -> choice c event arg))
       (Ok New_game_choices.default) args)
    run

let no_new_game _ =
  Error
    (Failure.cause ~repeats:true "no_handler"
       "new_game runs on the console only")

(* The fork's console action timeout for run_to_gate. *)
let run_to_gate_ms = 8000

let run_to_gate steps ~timeout_ms =
  Plza_walk.Gate_run.run (Steps.walk_game_steps steps) ~timeout_ms

(* The plan's timeout for each run at the far gate (plza-03.08b.plan.json). *)
let run_out_of_zone_1_ms = 5000

let run_out_of_zone_1 steps ~timeout_ms =
  Plza_walk.Map_walk.run_out_of_zone_one
    (Steps.walk_game_steps steps)
    ~timeout_ms

let check_out_of_zone_1 steps =
  Plza_walk.Map_walk.check_out_of_zone_one (Steps.walk_game_steps steps)

(* The fork's counts (PokemonLZA_AutoStoryConsoleActions.cpp). *)
let max_throws = 6
let max_rounds = 6

(* Wild Zone 1's actions, from 03.07 on. *)
let zone_actions =
  [
    ("run_to_gate", timed run_to_gate ~default:run_to_gate_ms);
    ( "catch_tutorial",
      no_args (fun steps -> Catches.catch_tutorial steps ~max_throws) );
    ( "battle_then_catch",
      no_args (fun steps -> Catches.battle_then_catch steps ~max_rounds) );
    ( "catch_in_zone",
      no_args (fun steps ->
          Zone_catch.run steps ~max_throws:Zone_catch.max_throws) );
    ("run_out_of_zone_1", timed run_out_of_zone_1 ~default:run_out_of_zone_1_ms);
    ("check_out_of_zone_1", no_args check_out_of_zone_1);
    ("claim_mable_research_reward", no_args Mable_reward.run);
  ]

(* The story's own actions, up to 03.06. *)
let story_actions ~new_game:run ~reload =
  [
    ("new_game", new_game run);
    ("confirm_new_game", no_args New_game_confirm.run);
    ( "opening_to_platform",
      timed Platform_wait.opening_to_platform ~default:opening_to_platform_ms );
    ( "wait_for_platform",
      timed (platform_or_reload ~reload) ~default:wait_for_platform_ms );
    ("set_text_speed_fast", no_args Text_speed.run);
    ("plus_skip", no_args Plus_skip.run);
    ("scene_to_choice", scene_to_choice);
    ("choose_0", no_args (fun steps -> Choose_row.run steps 0));
    ("choose_1", no_args (fun steps -> Choose_row.run steps 1));
    ("scene_to_battle", no_args scene_to_battle);
    ("scene_with_start_window", scene_with_start_window);
    ("scene_through_prompt", scene_through_prompt);
    ("story_battle", no_args Battle.run);
    ("talk_through_map_screen", no_args Map_talk.run);
    ( "climb_ladder",
      no_args (fun steps -> Plza_walk.Ladder_climb.run (talk_steps steps)) );
  ]

let game_actions ~new_game ~reload steps =
  List.map
    (fun (name, action) -> (name, action steps))
    (story_actions ~new_game ~reload @ zone_actions)

let scene steps (event : Plan.event) =
  match event.way with
  | None -> Scene_machine.run steps "scene" Scene_machine.default
  | Some "end_on_black_fade" ->
      Scene_machine.run steps "scene"
        { Scene_machine.default with end_on_black_fade = true }
  | Some "button_b" ->
      Scene_machine.run steps "scene" { Scene_machine.default with button = B }
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

let walk steps ~checkpoint_id ~jump (event : Plan.event)
    (own : Plza_rules.Action.t) =
  let walk_steps = Steps.walk_game_steps steps in
  let walk_only = walk_only checkpoint_id in
  let battle_ahead = Battle_jump.battle_ahead jump event in
  match own with
  | Walk args ->
      Battle_jump.after jump event
        (Plza_walk.Walk.run_event walk_steps ~walk_only ~battle_ahead event.id
           args)

(* Every handler runs through the jump to a story battle. *)
let jumping jump (name, action) =
  ( name,
    fun event args -> Battle_jump.run jump event (fun () -> action event args)
  )

let own_through jump steps ~checkpoint_id event own =
  Battle_jump.run jump event (fun () ->
      walk steps ~checkpoint_id ~jump event own)

let builtin_through jump steps event =
  Battle_jump.run jump event (fun () -> builtin steps event)

let no_save () =
  Error (Failure.cause ~repeats:true "no_save" "PLZA saves by autosave only")

let make ?(new_game = no_new_game) steps ~(checkpoint : Plan.checkpoint) ~reload
    : Game.t =
  let checkpoint_id = checkpoint.checkpoint_id in
  let jump = Battle_jump.make checkpoint ~log:steps.Steps.log in
  {
    run_own = own_through jump steps ~checkpoint_id;
    run_builtin = builtin_through jump steps;
    game_actions =
      List.map (jumping jump) (game_actions ~new_game ~reload steps);
    flag_holds = Resume_flags.holds steps;
    position = (fun () -> None);
    between_rounds = (fun () -> Ok ());
    save = no_save;
    reload;
    log = steps.log;
  }

(* The end check's failure, after the last event, as the engine's own end
   check names one. *)
let at_end (checkpoint : Plza_checkpoints.Plan.checkpoint) cause =
  {
    Plza_checkpoints.Failure.checkpoint_id = checkpoint.checkpoint_id;
    event_index = List.length checkpoint.events;
    event_id = "end";
    reason = Handler cause;
  }

let run_watched ?(end_check = fun () -> Ok ()) ~mode report game checkpoint =
  Plza_checkpoints.Plan_watch.run ~mode report (fun ~on_event ->
      Result.bind (Plza_checkpoints.Runner.run ~on_event game checkpoint)
        (fun () -> Result.map_error (at_end checkpoint) (end_check ())))
