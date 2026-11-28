(* One run of one checkpoint on the live emulator: a run folder, a daemon
   logging to it, the checkpoint from its start state through
   Frlg_checkpoints.Checkpoint_run with its declared end, then the saves the outcome
   asks for (the failure frame and state, or a passing end) while the session
   is still open, and the run's summary, KEEP and RESULTS.tsv row. The run
   shows the chain it is part of (Engine_series.Chain_progress, through [progress]),
   its plan and story lines on the daemon's watch page (Plan_watch);
   a Stop pressed there is a failure ("stopped by user") that repeats, so the
   series stops too. *)

open Engine_run
open Pokemon_engine
open Checkpoints_series
include Live_checkpoint

let options setup cp log : Frlg_checkpoints.Checkpoint_run.options =
  {
    (Plan_command.options { setup.common with log_file = None }) with
    (* Each checkpoint of the series reads its party: --party is only the
       first start's, for the Switch's start check (Console_session). *)
    party = None;
    program_options = setup.program_options;
    default_frame_model =
      (match setup.backend with Switch _ -> "switch" | Mgba _ -> "mgba");
    state =
      (match setup.backend with
      | Mgba _ -> Some cp.start_state
      | Switch _ -> None);
    log;
  }

(* After a passing round of a repeating checkpoint: whether its goal holds. *)
let goal_after cp log =
  Option.map
    (fun (r : Plan.repeat) ->
      Frlg_checkpoints.Checkpoint_run.goal_holds ~log ~id:cp.id r.until)
    cp.plan.repeat

(* On mGBA, the state at each event's start (Event_state_files). *)
let keep_event_state setup cp log =
  match setup.backend with
  | Mgba _ ->
      Some (Event_state_files.keep ~states:setup.states ~checkpoint:cp.id ~log)
  | Switch _ -> None

let run_checkpoint setup cp watch log () =
  match
    Frlg_checkpoints.Checkpoint_run.run ?end_at:cp.end_at
      ~on_event:(Frlg_checkpoints.Plan_watch.on_event watch)
      ?from_event:cp.partial
      ?keep_event_state:(keep_event_state setup cp log)
      (options setup cp log) setup.world cp.plan
    |> Result.map (fun () -> goal_after cp log)
  with
  | Ok goal -> (Passed { goal }, Console_runs.Passed)
  | Error failure ->
      (of_failure failure, Console_runs.outcome_of_failure failure.reason)

let on_stop watch log reason =
  log ("[Run] " ^ reason);
  let at = Option.value (Watch_report.current watch) ~default:"start" in
  (Failed { at; reason; repeats = true }, Console_runs.Stopped)

let on_raised e =
  ( Failed { at = "raised"; reason = Printexc.to_string e; repeats = false },
    Console_runs.Failed_event )

(* The checkpoint, shown on the watch page as it runs; a Stop there ends it
   at the event it was in. With how it ended, for the console's steps. *)
let checkpoint_outcome setup cp log =
  let watch = Frlg_checkpoints.Plan_watch.create cp.plan.checkpoint in
  Daemon_run.guard_session ~on_stop:(on_stop watch log) ~on_raised
    (run_checkpoint setup cp watch log)

let frame_path setup id =
  Frlg_checkpoints.Start_check.frame_file ~states:setup.states id

(* The start frame kept under the checkpoint's id: none for a start anywhere
   outdoors, which looks different from each save. *)
let start_frame_path setup cp =
  match cp.plan.checkpoint.start with
  | Some (Anywhere _) -> None
  | Some (Grid _ | Zone _) | None -> Some (frame_path setup cp.id)

(* On the Switch: initial screen check and back to the last save (unless already
   at start), then the start check and the run. *)
let console_run setup ~picture cp ~already_at_start log =
  let roster =
    Frlg_actions.Party_roster.(to_list (of_string setup.common.party))
  in
  let party = Console_session.start_party ~roster cp.before in
  let steps = Console_runs.before_run ~already_at_start in
  match
    Console_session.before ~log ~picture ~home_tile:setup.home_tile
      ~frame_path:(start_frame_path setup cp)
      ~start_path:
        (Frlg_checkpoints.Start_check.start_file ~states:setup.states
           cp.plan.checkpoint.start)
      ~steps party
  with
  | Error reason ->
      log ("[Console] " ^ reason);
      (Failed { at = "start"; reason; repeats = true }, Console_runs.Stopped)
  | Ok () -> checkpoint_outcome setup cp log

(* On the Switch, once the failure frame is saved: the steps after the run. *)
let console_after setup cp log (outcome, kind) =
  let steps =
    Console_runs.after_run ~save_after_pass:setup.save_after_pass kind
  in
  let next_frame = Option.map (frame_path setup) cp.next_id in
  match Console_session.after ~log ~next_frame steps with
  | Ok () -> outcome
  | Error reason -> Failed { at = "save"; reason; repeats = true }

(* In the session: the chain before and after this run, the checkpoint, then
   the outcome's saves. Each run has its own daemon, so each sends the chain
   for a page that is watching it. *)
let emulator_run setup cp log record =
  let path = Run_record.path record in
  let outcome, _ = checkpoint_outcome setup cp log in
  (match outcome with
  | Failed _ -> Daemon_run.save_failure ~log record ~save_states:true
  | Passed _
    when Event_range.keeps_end (partial_range cp) setup.policy
         || cp.plan.repeat <> None ->
      (* A round's end is the next round's start. *)
      Daemon_run.save ~log "end.ss" (fun () ->
          Effects.save_state (path "end.ss"))
  | Passed _ -> ());
  outcome

let switch_run setup ~picture cp ~already_at_start log record =
  let ((outcome, _) as ended) =
    console_run setup ~picture cp ~already_at_start log
  in
  (match outcome with
  | Failed _ -> Daemon_run.save_failure ~log record ~save_states:false
  | Passed _ -> ());
  console_after setup cp log ended

let in_session setup cp ~already_at_start ~progress ~log record
    (backend : Wire.backend) =
  let log = Watch_report.log log in
  Effects.show_run (progress None);
  let outcome =
    match setup.backend with
    | Mgba _ -> emulator_run setup cp log record
    | Switch _ ->
        switch_run setup ~picture:backend.viewport cp ~already_at_start log
          record
  in
  Effects.show_run (progress (Some (trial outcome)));
  outcome

let capped_note setup cp =
  Run_line.capped_note ~grind_cap:setup.common.grind_cap cp.plan

(* " from #13 trade_chding to #14 exit_...", so a partial pass is never taken
   for a whole one. *)
let partial_note cp =
  match events cp with
  | None -> ""
  | Some (first, last) -> Printf.sprintf " from %s to %s (partial)" first last

let run_label cp n ~attempt =
  let unit_name = if cp.plan.repeat = None then "run" else "round" in
  Series_daemons.run_name ~unit_name ~attempts:(cp.plan.retries + 1) ~id:cp.id
    ~n ~attempt ()

let mode_name setup cp =
  match cp.partial with
  | Some _ -> Event_range.mode_name
  | None -> Checkpoint_trials.mode_to_string setup.mode

let ending_of setup cp name outcome =
  let name = name ^ partial_note cp in
  let cap = capped_note setup cp in
  match outcome with
  | Passed { goal } ->
      Series_daemons.format_ending ~name
        ~suffix:(Run_line.goal_note goal ^ cap)
        (Ok ())
  | Failed { at; reason; _ } ->
      Series_daemons.format_ending ~name ~suffix:cap (Error (at, reason))

(* Attempt [attempt] of run [n] of [cp]: its folder and how it ended; [Error]
   when its folder could not be made. [progress] is the chain for the watch
   page before the attempt ([None]) and after it. *)
let run setup cp n ~attempt ~already_at_start ~progress =
  let attempts = cp.plan.retries + 1 in
  let name = run_label cp n ~attempt in
  let banner = Printf.sprintf "[Run] %s from %s" name cp.start_state in
  Series_daemons.start_and_run setup.daemons
    ?attempt:(if attempts > 1 then Some (attempt, attempts) else None)
    ?events:(events cp) ~runs_dir:setup.runs_dir ~checkpoint:cp.id
    ~mode:(mode_name setup cp) ~n ~failed ~ending:(ending_of setup cp name)
    ~banner
    (in_session setup cp ~already_at_start ~progress)
