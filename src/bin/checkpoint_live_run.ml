(* One run of one checkpoint on the live emulator: a run folder, a daemon
   logging to it, the checkpoint from its start state through
   Frlg_story.Checkpoint_run with its declared end, then the saves the outcome
   asks for (the failure frame and state, or a passing end) while the session
   is still open, and the run's summary, KEEP and RESULTS.tsv row. The run
   shows the chain it is part of (Story.Chain_progress, through [progress]),
   its plan and story lines on the daemon's watch page (Plan_watch);
   a Stop pressed there is a failure ("stopped by user") that repeats, so the
   series stops too. *)

open Story
include Live_checkpoint

(* A save the daemon may refuse (an older daemon, a bad path): logged, not
   fatal. *)
let save log what op =
  match op () with
  | (_ : int) -> log ("[Run] saved " ^ what)
  | exception Effects.Rpc_error e ->
      log (Printf.sprintf "[Run] could not save %s: %s" what e.message)

let options setup cp log : Frlg_story.Checkpoint_run.options =
  {
    (Checkpoint_command.options { setup.common with log_file = None }) with
    (* Each checkpoint of the series reads its party: --party is only the
       first start's, for the Switch's start check (Console_session). *)
    party = None;
    state =
      (match setup.backend with
      | Mgba _ -> Some cp.start_state
      | Switch _ -> None);
    log;
  }

(* On mGBA, the state at each event's start (Event_state_files). *)
let keep_event_state setup cp log =
  match setup.backend with
  | Mgba _ ->
      Some (Event_state_files.keep ~states:setup.states ~checkpoint:cp.id ~log)
  | Switch _ -> None

(* The checkpoint, shown on the watch page as it runs; a Stop there ends it
   at the event it was in. With how it ended, for the console's steps. *)
let checkpoint_outcome setup cp log =
  let watch = Frlg_story.Plan_watch.create cp.plan.checkpoint in
  match
    Frlg_story.Checkpoint_run.run ?end_at:cp.end_at
      ~on_event:(Frlg_story.Plan_watch.on_event watch)
      ?from_event:cp.partial
      ?keep_event_state:(keep_event_state setup cp log)
      (options setup cp log) setup.world cp.plan
  with
  | Ok () -> (Passed, Console_runs.Passed)
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
  Frlg_story.Start_check.frame_file ~states:setup.states id

(* On the Switch: back to the last save and the start check, then the run. *)
let console_run setup cp log =
  let roster =
    Frlg_actions.Party_roster.(to_list (of_string setup.common.party))
  in
  let party = Console_session.start_party ~roster cp.before in
  match
    Console_session.before ~log ~frame_path:(frame_path setup cp.id) party
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

let save_op path file : Run_record.save -> unit -> int = function
  | Frame -> fun () -> Effects.save_frame (path file)
  | State -> fun () -> Effects.save_state (path file)

(* The frame, and the state where the backend keeps states (not the Switch). *)
let save_failure log path ~save_states =
  List.iter
    (fun (file, kind) -> save log file (save_op path file kind))
    (Run_record.failure_saves ~save_states)

(* In the session: the chain before and after this run, the checkpoint, then
   the outcome's saves. Each run has its own daemon, so each sends the chain
   for a page that is watching it. *)
let emulator_run setup cp log path =
  let outcome, _ = checkpoint_outcome setup cp log in
  (match outcome with
  | Failed _ -> save_failure log path ~save_states:true
  | Passed when Event_range.keeps_end (partial_range cp) setup.policy ->
      save log "end.ss" (fun () -> Effects.save_state (path "end.ss"))
  | Passed -> ());
  outcome

let switch_run setup cp log path =
  let ((outcome, _) as ended) = console_run setup cp log in
  (match outcome with
  | Failed _ -> save_failure log path ~save_states:false
  | Passed -> ());
  console_after setup cp log ended

let in_session setup cp ~progress record log () =
  let log = Watch_report.log log in
  Effects.show_run (progress None);
  let path = Run_record.path record in
  let outcome =
    match setup.backend with
    | Mgba _ -> emulator_run setup cp log path
    | Switch _ -> switch_run setup cp log path
  in
  Effects.show_run (progress (Some (trial outcome)));
  outcome

let live setup cp ~progress record log (daemon : Daemon_process.t) =
  match
    Live.run ~port:daemon.port (in_session setup cp ~progress record log)
  with
  | outcome -> outcome
  | exception Effects.Disconnected e ->
      Failed { at = "session"; reason = "disconnected: " ^ e; repeats = false }
  | exception Unix.Unix_error (e, f, _) ->
      Failed
        {
          at = "session";
          reason = f ^ ": " ^ Unix.error_message e;
          repeats = true;
        }

let start_daemon setup record cp (port, watch) =
  Daemon_process.start ?watch ~flags:setup.daemon_flags ~daemon:setup.daemon
    ~backend:setup.backend ~port
    ~wire_log:(Run_record.path record "wire.jsonl")
    ~out_file:(Run_record.path record "daemon.out")
    ~checkpoint:cp.id ()

(* The ports the last daemon bound, else the flags' (0: any); the flags' when
   those are taken now. *)
let start_sticky setup record cp =
  let asked = (setup.common.port, setup.watch) in
  let again =
    match !(setup.bound) with
    | None -> asked
    | Some (port, page) ->
        let keep (w : Daemon_process.watch) =
          { w with port = Option.value page ~default:w.port }
        in
        (port, Option.map keep setup.watch)
  in
  match start_daemon setup record cp again with
  | Error _ when again <> asked -> start_daemon setup record cp asked
  | started -> started

(* Prints the page's URLs when they are new: at the first run, or when the
   last run's ports were taken. *)
let announce setup (daemon : Daemon_process.t) =
  let bound = Some (daemon.port, daemon.watch_port) in
  (match (setup.watch, daemon.watch_port) with
  | Some w, Some port when !(setup.bound) <> bound ->
      Watch_urls.print ~listen:w.listen ~token:w.token ~port
  | _ -> ());
  setup.bound := bound

let with_daemon setup record cp body =
  match start_sticky setup record cp with
  | Error reason -> Failed { at = "daemon"; reason; repeats = true }
  | Ok daemon ->
      announce setup daemon;
      Fun.protect
        ~finally:(fun () -> Daemon_process.stop daemon)
        (fun () -> body daemon)

(* With --grind-battles: " (grind capped at N; skipped: ...)", so a capped
   pass is never taken for a full one. *)
let capped_note setup cp =
  let skipped cap =
    snd
      (Frlg_story.Checkpoint_run.capped_postconditions ~grind_cap:(Some cap)
         cp.plan)
  in
  match setup.common.grind_cap with
  | None -> ""
  | Some cap when skipped cap = [] -> Printf.sprintf " (grind capped at %d)" cap
  | Some cap ->
      Printf.sprintf " (grind capped at %d; skipped: %s)" cap
        (String.concat "; " (skipped cap))

(* " attempt 2/4" when the plan allows retries. *)
let attempt_note cp attempt =
  if cp.plan.retries = 0 then ""
  else Printf.sprintf " attempt %d/%d" attempt (cp.plan.retries + 1)

(* " from #13 trade_chding to #14 exit_...", so a partial pass is never taken
   for a whole one. *)
let partial_note cp =
  match events cp with
  | None -> ""
  | Some (first, last) -> Printf.sprintf " from %s to %s (partial)" first last

let summary setup cp n ~attempt outcome =
  let run =
    Printf.sprintf "%s run %d%s%s" cp.id n (attempt_note cp attempt)
      (partial_note cp)
  in
  let line =
    match outcome with
    | Passed -> "PASS " ^ run
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
  print_endline ("[Run] " ^ run.record.dir ^ ": " ^ line);
  let ending : Run_record.ending =
    match outcome with
    | Passed -> { result = "pass"; at = ""; reason = "" }
    | Failed { at; reason; _ } -> { result = "fail"; at; reason }
  in
  Run_record.finish ~runs_dir:setup.runs_dir run ~summary:line ending

(* Attempt [attempt] of run [n] of [cp]: its folder and how it ended.
   [progress] is the chain for the watch page before the attempt ([None]) and
   after it. *)
let run setup cp n ~attempt ~progress =
  let attempts = cp.plan.retries + 1 in
  let run =
    Run_record.start
      ?attempt:(if attempts > 1 then Some (attempt, attempts) else None)
      ?events:(events cp) ~runs_dir:setup.runs_dir setup.info ~checkpoint:cp.id
      ~mode:(mode_name setup cp)
  in
  let record = run.record in
  let log, close = Run_record.story_log record in
  log
    (Printf.sprintf "[Run] %s run %d%s from %s" cp.id n
       (attempt_note cp attempt) cp.start_state);
  let outcome =
    with_daemon setup record cp (live setup cp ~progress record log)
  in
  close ();
  record_outcome setup cp run n ~attempt outcome;
  (record, outcome)
