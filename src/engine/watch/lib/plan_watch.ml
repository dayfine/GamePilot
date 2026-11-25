module Make (T : Engine_rules.GAME_RULES) (Raw : Engine_plan.Plan.RAW) = struct
  module Plan = Engine_plan.Plan.Make (T) (Raw)

  let create (checkpoint : Plan.checkpoint) =
    Watch_report.create ~checkpoint:checkpoint.checkpoint_id
      (List.map (fun (e : Plan.event) -> e.id) checkpoint.events)

  (* The event's state on the page and its detail (a failure's reason, the
     flag a skip held on). *)
  let to_watch : string Engine_run.Event_progress.t -> _ = function
    | Started -> (Wire.Watch.Current, "")
    | Passed -> (Wire.Watch.Done, "")
    | Skipped flag -> (Wire.Watch.Skipped, flag)
    | Failed reason -> (Wire.Watch.Failed, reason)

  let on_event report index progress =
    let state, detail = to_watch progress in
    Watch_report.set report index state detail

  let run ~mode report f =
    Watch_report.start_run report ~mode;
    let result = f ~on_event:(on_event report) in
    Watch_report.end_run report ~passed:(Result.is_ok result);
    result
end
