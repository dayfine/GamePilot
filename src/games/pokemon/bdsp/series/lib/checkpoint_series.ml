open Engine_run
open Engine_series
open Live_run
module B = Bdsp_engine
module Chain = Series_chain

let ( let* ) = Result.bind

type failure = { at : string; reason : string; repeats : bool }
type outcome = Passed | Failed of failure

type action_runner =
  log:(string -> unit) ->
  picture:Wire.box ->
  options:Run_options.t ->
  Bdsp_rules.Action.t ->
  (unit, Failure.cause) result

type program = {
  check_plans : B.Plan.t list -> (unit, string) result;
  daemon_flags : string list;
  initial_screen : B.Plan.t -> Switch.Initial_screen.expectation;
  run_action : action_runner;
}

type setup = {
  flags : Flags.t;
  options : Run_options.t;
  daemons : Series_daemons.t;
  initial_screen : B.Plan.t -> Switch.Initial_screen.expectation;
  run_action : action_runner;
}

let load_plan ~plan_dir id =
  B.Plan_decode.load (Plan_folder.plan_file ~plan_dir id)

let failed ?(repeats = false) at reason = Failed { at; reason; repeats }

let of_runner ({ at; reason; repeats } : Daemon_run.failed) =
  failed ~repeats at reason

let of_engine_failure (f : B.Failure.t) =
  Failed
    {
      at = Printf.sprintf "#%d %s" (f.event_index + 1) f.event_id;
      reason = B.Failure.reason_to_string f.reason;
      repeats = B.Failure.repeats f;
    }

let trial_of = function
  | Passed -> Checkpoint_trials.Passed
  | Failed { at; repeats; _ } -> Checkpoint_trials.Failed { at; repeats }

let no_handler (event : B.Plan.event) =
  Error
    (Failure.cause ~repeats:true "no_handler"
       (event.id ^ ": BDSP checkpoint runs BDSP actions only"))

let no_save_reload () =
  Error
    (Failure.cause ~repeats:true "no_save_reload"
       "BDSP actions manage their own in-game saving")

let make_game setup ~log ~picture : B.Game.t =
  {
    run_own =
      (fun _event action ->
        setup.run_action ~log ~picture ~options:setup.options action);
    run_builtin = no_handler;
    game_actions = [];
    flag_holds = (fun _ -> false);
    position = (fun () -> None);
    between_rounds = (fun () -> Ok ());
    save = no_save_reload;
    reload = no_save_reload;
    log;
  }

let run_checkpoint setup ~log ~picture report (plan : B.Plan.t) =
  let game = make_game setup ~log ~picture in
  Switch.Stick_wake.run ();
  match
    B.Plan_watch.run ~mode:"testing" report (fun ~on_event ->
        B.Runner.run ~on_event game plan.checkpoint)
  with
  | Ok () -> Passed
  | Error f -> of_engine_failure f

let run_guarded setup ~log ~picture ~already_at_start report plan =
  let end_failed () = Watch_report.end_run report ~passed:false in
  match
    Switch.Initial_screen.check_unless_chained ~already_at_start ~log ~picture
      (setup.initial_screen plan)
  with
  | Error reason ->
      end_failed ();
      failed ~repeats:true "start" reason
  | Ok () ->
      Daemon_run.guard_session
        ~on_stop:(fun reason ->
          end_failed ();
          failed ~repeats:true "stopped" reason)
        ~on_raised:(fun e ->
          end_failed ();
          failed "raised" (Printexc.to_string e))
        (fun () -> run_checkpoint setup ~log ~picture report plan)

let in_session setup ~already_at_start plan ~log record (backend : Wire.backend)
    =
  let picture = backend.viewport in
  let log = Watch_report.log log in
  let report = B.Plan_watch.create plan.B.Plan.checkpoint in
  let outcome = run_guarded setup ~log ~picture ~already_at_start report plan in
  (match outcome with
  | Failed _ -> Daemon_run.save_failure ~log record ~save_states:false
  | Passed -> ());
  outcome

let ending_of name = function
  | Passed -> Series_daemons.format_ending ~name (Ok ())
  | Failed { at; reason; _ } ->
      Series_daemons.format_ending ~name (Error (at, reason))

let run_trial setup (plan : B.Plan.t) (t : Chain.trial) ~progress:_ =
  let id = plan.checkpoint.checkpoint_id in
  let name = Series_daemons.run_name ~id ~n:t.number ~attempt:1 () in
  let already_at_start = Chain.trial_already_at_start t ~attempt:1 in
  match
    Series_daemons.start_and_run setup.daemons ~runs_dir:setup.flags.runs_dir
      ~checkpoint:id ~mode:"testing" ~n:t.number ~failed:of_runner
      ~ending:(ending_of name) ~banner:("[Run] " ^ name)
      (in_session setup ~already_at_start plan)
  with
  | Error reason -> Ok (failed ~repeats:true "run folder" reason)
  | Ok (_, outcome) -> Ok outcome

let load_checked program ~plan_dir ids =
  let* plans =
    List.fold_left
      (fun acc id ->
        let* acc = acc in
        let* plan = load_plan ~plan_dir id in
        Ok (acc @ [ plan ]))
      (Ok []) ids
  in
  let* () = program.check_plans plans in
  Ok plans

let rec last_item = function
  | [] -> None
  | [ x ] -> Some x
  | _ :: rest -> last_item rest

let select_range ~plan_dir (f : Flags.t) =
  let* all = Plan_folder.checkpoint_ids plan_dir in
  match (f.from_id, f.to_id, all) with
  | Some from_id, Some to_id, _ ->
      Plan_folder.select_range ~plan_dir ~from_id ~to_id
  | Some from_id, None, _ ->
      Plan_folder.select_range ~plan_dir ~from_id ~to_id:from_id
  | None, Some to_id, first :: _ ->
      Plan_folder.select_range ~plan_dir ~from_id:first ~to_id
  | None, None, first :: _ ->
      let to_id = Option.value (last_item all) ~default:first in
      Plan_folder.select_range ~plan_dir ~from_id:first ~to_id
  | None, _, [] -> Error ("no *.plan.json in " ^ plan_dir)

let switch_only : Daemon_process.backend -> _ = function
  | Mgba _ -> Error "BDSP runs on the Switch only: --backend switch"
  | Switch _ -> Ok ()

let setup_of program (f : Flags.t) ~program_fields ~options ~from_id ~to_id ~ids
    ~backend ~viewport =
  let info : Run_record.info =
    {
      kind = Checkpoints;
      program = program_fields;
      from_id;
      to_id;
      backend = f.backend;
      options = Run_options.pairs options;
    }
  in
  let mode = Checkpoint_trials.mode_to_string Testing in
  {
    flags = f;
    options;
    daemons =
      Series_daemons.create_for_runs ~daemon:f.daemon ~runs_dir:f.runs_dir
        ~backend ~viewport ~program_flags:program.daemon_flags
        ~daemon_flags:f.daemon_flags ~port:f.port ~watch:f.watch
        { info; mode; checkpoints = ids };
    initial_screen = program.initial_screen;
    run_action = program.run_action;
  }

let run_series program ~program_fields ~options ~viewport plan_dir args =
  let* f = Flags.parse args in
  let* () = Flags.takes f in
  let* range = select_range ~plan_dir f in
  let* backend = Run_flags.daemon_backend f Testing in
  let* () = switch_only backend in
  let* viewport = viewport in
  let* policy = Checkpoint_trials.policy ?runs:f.runs Testing in
  let* plans = load_checked program ~plan_dir range.selected in
  let setup =
    setup_of program f ~program_fields ~options ~from_id:range.from_id
      ~to_id:range.to_id ~ids:range.selected ~backend ~viewport
  in
  let hooks : (B.Plan.t, B.Plan.t, outcome) Series_runner.hooks =
    {
      entry_id = (fun (p : B.Plan.t) -> p.checkpoint.checkpoint_id);
      prepare = (fun plan ~next:_ -> Ok plan);
      run_trial = run_trial setup;
      trial_of;
      verdict_note = (fun _ -> "");
      on_pass = (fun _ ~next:_ _ -> ());
    }
  in
  let passed =
    Series_runner.run ~mode:Testing ~policy ~now_ms:Run_record.now_ms
      ~log:print_endline hooks plans
  in
  Ok
    (Series_daemons.finish_series setup.daemons ~close_game:f.close_game ~passed
       ())
