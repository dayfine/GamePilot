(* A plan's run on the watch page (Watch_report): its events as the steps,
   moved by the runner's progress. *)

let create (checkpoint : Pokemon_checkpoints.Plan.checkpoint) =
  Watch_report.create ~checkpoint:checkpoint.checkpoint_id
    (List.map
       (fun (e : Pokemon_checkpoints.Plan.event) -> e.id)
       checkpoint.events)

(* The event's state on the page and its detail (a failure's reason, the flag
   a skip held on). *)
let to_watch : string Engine_run.Event_progress.t -> _ = function
  | Started -> (Wire.Watch.Current, "")
  | Passed -> (Wire.Watch.Done, "")
  | Skipped flag -> (Wire.Watch.Skipped, flag)
  | Failed reason -> (Wire.Watch.Failed, reason)

let on_event report index progress =
  let state, detail = to_watch progress in
  Watch_report.set report index state detail

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
    log;
  }

(* In the session: [plan] through the checkpoint runner, shown with its run
   in [mode] from start to end; every story line to the page too. [actions]
   (made for that log) are the caller's own game actions: a shadow plan's. *)
let run ~mode ?(actions = fun _ -> []) (options : Checkpoint_run.options) world
    (plan : Pokemon_checkpoints.Plan.t) =
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
