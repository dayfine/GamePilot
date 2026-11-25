module Failure = Engine_run.Failure
module Game = Plza_engine.Game
module Plan = Plza_engine.Plan

let run_from = "03.03"
let walk_only id = String.compare id run_from < 0

let builtin (event : Plan.event) =
  Error
    (Failure.cause ~repeats:true "no_handler"
       (event.id ^ ": PLZA runs no talk, answer or save event"))

let walk steps ~checkpoint_id (event : Plan.event) (own : Plza_rules.Action.t) =
  let walk_only = walk_only checkpoint_id in
  match own with
  | Walk args -> Plza_walk.Walk.run_event steps ~walk_only event.id args

let no_save () =
  Error (Failure.cause ~repeats:true "no_save" "PLZA saves by autosave only")

let make (steps : Plza_walk.Walk.game_steps) ~(checkpoint : Plan.checkpoint)
    ~reload : Game.t =
  let checkpoint_id = checkpoint.checkpoint_id in
  {
    run_own = walk steps ~checkpoint_id;
    run_builtin = builtin;
    game_actions = [];
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
