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
      steps.Story_steps.log
        "[PLZA] platform wait: no controls hint (it fades when idle); \
         reloading the latest autosave to see it fresh";
      Result.bind (reload ()) (fun () ->
          Platform_wait.wait_for_platform steps ~timeout_ms)
  | outcome -> outcome

(* The fork's scene with "stop_at_choice": its "button" A or B (A when
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

let game_actions ~reload steps =
  List.map
    (fun (name, action) -> (name, action steps))
    [
      ("confirm_new_game", no_args New_game_confirm.run);
      ( "opening_to_platform",
        timed Platform_wait.opening_to_platform ~default:opening_to_platform_ms
      );
      ( "wait_for_platform",
        timed (platform_or_reload ~reload) ~default:wait_for_platform_ms );
      ("set_text_speed_fast", no_args Text_speed.run);
      ("plus_skip", no_args Plus_skip.run);
      ("scene_to_choice", scene_to_choice);
      ("choose_0", no_args (fun steps -> Choose_row.run steps 0));
      ("choose_1", no_args (fun steps -> Choose_row.run steps 1));
    ]

let scene steps (event : Plan.event) =
  match event.way with
  | None -> Scene_machine.run steps "scene" Scene_machine.default
  | Some "end_on_black_fade" ->
      Scene_machine.run steps "scene"
        { Scene_machine.default with end_on_black_fade = true }
  | Some way ->
      bad_args event ("a scene's action is end_on_black_fade, not " ^ way)

let builtin steps (event : Plan.event) =
  match event.kind with
  | Scene -> scene steps event
  | _ ->
      Error
        (Failure.cause ~repeats:true "no_handler"
           (event.id ^ ": PLZA runs no talk, answer or save event"))

let walk steps ~checkpoint_id (event : Plan.event) (own : Plza_rules.Action.t) =
  match own with
  | Walk args ->
      Plza_walk.Walk.run_event
        (Story_steps.walk_game_steps steps)
        ~walk_only:(walk_only checkpoint_id) event.id args

let make steps ~checkpoint_id ~reload : Game.t =
  {
    run_own = walk steps ~checkpoint_id;
    run_builtin = builtin steps;
    game_actions = game_actions ~reload steps;
    flag_holds = (fun _ -> false);
    position = (fun () -> None);
    between_rounds = (fun () -> Ok ());
    save =
      (fun () ->
        Error
          (Failure.cause ~repeats:true "no_save" "PLZA saves by autosave only"));
    reload;
    log = steps.log;
  }

let run_watched ~mode report game checkpoint =
  Plza_checkpoints.Plan_watch.run ~mode report (fun ~on_event ->
      Plza_checkpoints.Runner.run ~on_event game checkpoint)
