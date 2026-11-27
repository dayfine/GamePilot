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

(* The checkpoint, shown on the watch page as it runs; a Stop there ends it
   at the event it was in. With how it ended, for the console's steps. *)
let checkpoint_outcome setup cp log =
  let watch = Frlg_checkpoints.Plan_watch.create cp.plan.checkpoint in
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
  | exception (Effects.Disconnected _ as e) -> raise e
  | exception Effects.Stop_requested reason ->
      log ("[Run] " ^ reason);
      let at = Option.value (Watch_report.current watch) ~default:"start" in
      (Failed { at; reason; repeats = true }, Stopped)
  | exception e ->
      ( Failed { at = "raised"; reason = Printexc.to_string e; repeats = false },
        Failed_event )

let frame_path setup id =
  Frlg_checkpoints.Start_check.frame_file ~states:setup.states id

(* The start frame kept under the checkpoint's id: none for a start anywhere
   outdoors, which looks different from each save. *)
let start_frame_path setup cp =
  match cp.plan.checkpoint.start with
  | Some (Anywhere _) -> None
  | Some (Grid _ | Zone _) | None -> Some (frame_path setup cp.id)

(* On the Switch: initial screen check, back to the last save and the start
   check, then the run. *)
let console_run setup ~picture cp log =
  let roster =
    Frlg_actions.Party_roster.(to_list (of_string setup.common.party))
  in
  let party = Console_session.start_party ~roster cp.before in
  match
    Console_session.before ~log ~picture ~home_tile:setup.home_tile
      ~frame_path:(start_frame_path setup cp)
      ~start_path:
        (Frlg_checkpoints.Start_check.start_file ~states:setup.states
           cp.plan.checkpoint.start)
      party
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

let switch_run setup ~picture cp log record =
  let ((outcome, _) as ended) = console_run setup ~picture cp log in
  (match outcome with
  | Failed _ -> Daemon_run.save_failure ~log record ~save_states:false
  | Passed _ -> ());
  console_after setup cp log ended

let in_session setup cp ~progress record log (backend : Wire.backend) =
  let log = Watch_report.log log in
  Effects.show_run (progress None);
  let outcome =
    match setup.backend with
    | Mgba _ -> emulator_run setup cp log record
    | Switch _ -> switch_run setup ~picture:backend.viewport cp log record
  in
  Effects.show_run (progress (Some (trial outcome)));
  outcome

let live setup cp ~progress record log (daemon : Daemon_process.t) =
  Daemon_run.in_session ~failed ~dir:record.Run_record.dir (fun () ->
      Live.run_with_backend ~port:daemon.port
        (in_session setup cp ~progress record log))

let with_daemon setup run n body =
  Series_daemons.with_daemon setup.daemons ~failed run ~n body

let capped_note setup cp =
  Run_line.capped_note ~grind_cap:setup.common.grind_cap cp.plan

(* " from #13 trade_chding to #14 exit_...", so a partial pass is never taken
   for a whole one. *)
let partial_note cp =
  match events cp with
  | None -> ""
  | Some (first, last) -> Printf.sprintf " from %s to %s (partial)" first last

let summary setup cp n ~attempt outcome =
  let run =
    Run_line.run_name cp.id cp.plan n
    ^ Run_line.attempt_note cp.plan attempt
    ^ partial_note cp
  in
  let line =
    match outcome with
    | Passed { goal } -> "PASS " ^ run ^ Run_line.goal_note goal
    | Failed { at; reason; _ } ->
        Printf.sprintf "FAIL %s at %s: %s" run at reason
  in
  line ^ capped_note setup cp

let mode_name setup cp =
  match cp.partial with
  | Some _ -> Event_range.mode_name
  | None -> Checkpoint_trials.mode_to_string setup.mode

let record_outcome setup cp (run : Run_record.run) n ~attempt outcome =
  let line = summary setup cp n ~attempt outcome in
  let ending : Run_record.ending =
    match outcome with
    | Passed _ -> { result = "pass"; at = ""; reason = "" }
    | Failed { at; reason; _ } -> { result = "fail"; at; reason }
  in
  Series_daemons.finish setup.daemons ~runs_dir:setup.runs_dir run ~summary:line
    ending

(* The attempt in its folder: the folder and how it ended. *)
let run_in setup cp n ~attempt ~progress (run : Run_record.run) =
  let record = run.record in
  let log, close = Run_record.run_log record in
  log
    (Printf.sprintf "[Run] %s%s from %s"
       (Run_line.run_name cp.id cp.plan n)
       (Run_line.attempt_note cp.plan attempt)
       cp.start_state);
  let outcome = with_daemon setup run n (live setup cp ~progress record log) in
  close ();
  record_outcome setup cp run n ~attempt outcome;
  (record, outcome)

(* Attempt [attempt] of run [n] of [cp]: its folder and how it ended; [Error]
   when its folder could not be made. [progress] is the chain for the watch
   page before the attempt ([None]) and after it. *)
let run setup cp n ~attempt ~progress =
  let attempts = cp.plan.retries + 1 in
  Result.map
    (run_in setup cp n ~attempt ~progress)
    (Run_record.start
       ?attempt:(if attempts > 1 then Some (attempt, attempts) else None)
       ?events:(events cp) ~runs_dir:setup.runs_dir setup.info ~checkpoint:cp.id
       ~mode:(mode_name setup cp))
