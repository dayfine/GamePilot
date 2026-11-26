(* A plan's run on the watch page (Watch_report): the engine's
   (Pokemon_engine.Plan_watch), with FireRed's runs around it. *)

let create = Pokemon_engine.Plan_watch.create
let on_event = Pokemon_engine.Plan_watch.on_event

(* The options of a run that loads no state: the plan's own events go back to
   the save. *)
let options log : Checkpoint_run.options =
  {
    state = None;
    party = None;
    center = None;
    grind_cap = None;
    gait = Running;
    end_check_only = false;
    program_options = Run_options.none;
    log;
  }

(* In the session: [plan] through the checkpoint runner, shown with its run
   in [mode] from start to end; every story line to the page too. [actions]
   (made for that log) are the caller's own game actions: a shadow plan's. *)
let run ~mode ?(actions = fun _ -> []) (options : Checkpoint_run.options) world
    (plan : Pokemon_engine.Plan.t) =
  let report = create plan.checkpoint in
  Watch_report.start_run report ~mode;
  let log = Watch_report.log options.log in
  match
    Checkpoint_run.run ~on_event:(on_event report) ~actions:(actions log)
      { options with log } world plan
  with
  | result ->
      Watch_report.end_run report ~passed:(Result.is_ok result);
      result
  | exception e ->
      Watch_report.end_run report ~passed:false;
      raise e

let run_shadow ~mode ~log world plan actions =
  run ~mode ~actions (options log) world plan
