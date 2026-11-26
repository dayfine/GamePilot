open Engine_run
module P = Plza_engine
module Game = Plza_bank_home.Bank_home_game
module Flags = Bank_home_flags

let ( let* ) = Result.bind

type outcome = Passed | Failed of Live_run.Daemon_run.failed

type setup = {
  flags : Flags.t;
  policy : Checkpoint_trials.policy;
  info : Run_record.info;
  daemons : Live_run.Series_daemons.t;
  options : Run_options.t;
  templates : Game.templates;
}

let failed ?(repeats = false) at reason = Failed { at; reason; repeats }
let of_runner (f : Live_run.Daemon_run.failed) = Failed f

let trial = function
  | Passed -> Checkpoint_trials.Passed
  | Failed { at; repeats; _ } -> Checkpoint_trials.Failed { at; repeats }

let of_engine (f : P.Failure.t) =
  failed ~repeats:(P.Failure.repeats f)
    (Printf.sprintf "#%d %s" (f.event_index + 1) f.event_id)
    (P.Failure.reason_to_string f.reason)

(* The start check's failure, as the runner names one before the first
   event. *)
let at_start (checkpoint : P.Plan.checkpoint) cause : P.Failure.t =
  {
    checkpoint_id = checkpoint.checkpoint_id;
    event_index = 0;
    event_id = "start";
    reason = Handler cause;
  }

let run_checkpoint setup ~log ~picture report (plan : P.Plan.t) =
  let game = Game.make ~log ~picture ~options:setup.options setup.templates in
  P.Plan_watch.run ~mode:"testing" report (fun ~on_event ->
      let* () =
        Result.map_error (at_start plan.checkpoint)
          (Game.start_check ~log setup.templates)
      in
      P.Runner.run ~on_event game plan.checkpoint)

let in_session setup ~log record plan (backend : Wire.backend) =
  let log = Watch_report.log log in
  let report = P.Plan_watch.create plan.P.Plan.checkpoint in
  let outcome =
    match run_checkpoint setup ~log ~picture:backend.viewport report plan with
    | Ok () -> Passed
    | Error f -> of_engine f
    | exception Effects.Stop_requested why ->
        Watch_report.end_run report ~passed:false;
        failed ~repeats:true "stopped" why
  in
  (match outcome with
  | Failed _ -> Live_run.Daemon_run.save_failure ~log record ~save_states:false
  | Passed -> ());
  outcome

let live setup ~log record plan (daemon : Live_run.Daemon_process.t) =
  Live_run.Daemon_run.in_session ~failed:of_runner ~dir:record.Run_record.dir
    (fun () ->
      Live.run_with_backend ~port:daemon.port
        (in_session setup ~log record plan))

let summary name = function
  | Passed -> "PASS " ^ name
  | Failed { at; reason; _ } ->
      Printf.sprintf "FAIL %s at %s: %s" name at reason

let run_in setup plan n (run : Run_record.run) =
  let name =
    Printf.sprintf "%s run %d" plan.P.Plan.checkpoint.checkpoint_id n
  in
  let log, close = Run_record.story_log run.record in
  log ("[Run] " ^ name);
  let outcome =
    Live_run.Series_daemons.with_daemon setup.daemons ~failed:of_runner run ~n
      (live setup ~log run.record plan)
  in
  close ();
  let ending : Run_record.ending =
    match outcome with
    | Passed -> { result = "pass"; at = ""; reason = "" }
    | Failed { at; reason; _ } -> { result = "fail"; at; reason }
  in
  Live_run.Series_daemons.finish setup.daemons ~runs_dir:setup.flags.runs_dir
    run ~summary:(summary name outcome) ending;
  outcome

let run setup (plan : P.Plan.t) n =
  Result.map
    (fun run -> run_in setup plan n run)
    (Run_record.start ~runs_dir:setup.flags.runs_dir setup.info
       ~checkpoint:plan.checkpoint.checkpoint_id ~mode:"testing")

let runs_of setup (plan : P.Plan.t) =
  let id = plan.checkpoint.checkpoint_id in
  match
    fst (Checkpoint_trials.until_decided setup.policy ~trial (run setup plan))
  with
  | Checkpoint_trials.Run_again -> false
  | Checkpoint_passed { passes; runs } ->
      Printf.printf "[Checkpoints] %s: passed (%d of %d runs)\n%!" id passes
        runs;
      true
  | Stopped why ->
      Printf.printf "[Checkpoints] %s: stopped: %s\n%!" id why;
      false

let rec chain setup = function
  | [] -> 0
  | plan :: rest -> if runs_of setup plan then chain setup rest else 1

let load_checked ~plan_dir options ids =
  List.fold_left
    (fun plans id ->
      let* plans = plans in
      let* plan =
        P.Plan_decode.load (Engine_series.Plan_folder.plan_file ~plan_dir id)
      in
      let* () = Game.check_plan options plan in
      Ok (plans @ [ plan ]))
    (Ok []) ids

let selected ~plan_dir (f : Flags.t) =
  let* from_id = Run_flags.required "--from" f.from_id in
  let* to_id = Run_flags.required "--to" f.to_id in
  let* ids = Engine_series.Plan_folder.checkpoint_ids plan_dir in
  let* ids, _ = Engine_series.Plan_folder.select ids ~from_id ~to_id in
  Ok (from_id, to_id, ids)

let switch_only : Live_run.Daemon_process.backend -> _ = function
  | Mgba _ -> Error "plza.bank-home runs on the Switch only: --backend switch"
  | Switch _ -> Ok ()

let daemons (f : Flags.t) backend ~viewport series =
  Live_run.Series_daemons.create ~daemon:f.daemon ~backend ~port:f.port
    ~flags:
      (Live_run.Daemon_process.viewport_args backend viewport @ f.daemon_flags)
    ~watch:
      (Live_run.Watch_hub.for_runs_dir ~daemon:f.daemon ~runs_dir:f.runs_dir
         f.watch)
    series

let run_series ~program ~options ~viewport plan_dir args =
  let* f = Flags.parse args in
  let* () = Flags.takes f in
  let* from_id, to_id, ids = selected ~plan_dir f in
  let* backend = Run_flags.daemon_backend f Checkpoint_trials.Testing in
  let* () = switch_only backend in
  let* viewport = viewport in
  let* policy =
    Checkpoint_trials.policy ?runs:f.runs Checkpoint_trials.Testing
  in
  let* plans = load_checked ~plan_dir options ids in
  let* templates = Home_templates.load () in
  let info : Run_record.info =
    {
      kind = Checkpoints;
      program;
      from_id;
      to_id;
      backend = f.backend;
      options = Run_options.pairs options;
    }
  in
  let mode = Checkpoint_trials.mode_to_string Testing in
  let daemons = daemons f backend ~viewport { info; mode; checkpoints = ids } in
  let setup = { flags = f; policy; info; daemons; options; templates } in
  let code = chain setup plans in
  Live_run.Series_daemons.finished daemons ~passed:(code = 0);
  Ok code
