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
  flags : unit Run_flags.flags;
  options : Run_options.t;
  daemons : Series_daemons.t;
  initial_screen : B.Plan.t -> Switch.Initial_screen.expectation;
  run_action : action_runner;
}

let load_plan ~plan_dir id =
  B.Plan_decode.load (Plan_folder.plan_file ~plan_dir id)

let load_title ~plan_dir id =
  Result.map
    (fun (p : B.Plan.t) -> (p.checkpoint.checkpoint_id, p.checkpoint.title))
    (load_plan ~plan_dir id)

let run_save_game ~log ~picture () =
  match Bdsp_actions.Save_game.save_game ~log ~picture () with
  | Ok () -> Ok ()
  | Error msg -> Error (Failure.cause ~repeats:true "save_game_failed" msg)

let default_program ~run_action =
  {
    check_plans = (fun _ -> Ok ());
    daemon_flags = [];
    initial_screen = (fun _ -> Switch.Initial_screen.In_game_or_resume None);
    run_action;
  }

let failed ~repeats ~at ~reason = Failed { at; reason; repeats }

let result_of = function
  | Passed -> Ok ()
  | Failed { at; reason; _ } -> Error (at, reason)

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

let run_trial setup (plan : B.Plan.t) (t : Chain.trial) =
  let checkpoint_id = plan.checkpoint.checkpoint_id in
  let already_at_start = Chain.trial_already_at_start t ~attempt:1 in
  Ok
    (Switch_series.run_attempt ~daemons:setup.daemons
       ~runs_dir:setup.flags.runs_dir ~checkpoint_id ~n:t.number ~attempt:1
       ~already_at_start
       ~expectation:(setup.initial_screen plan)
       ~create_report:(fun () -> B.Plan_watch.create plan.B.Plan.checkpoint)
       ~failed ~result_of
       (fun ~log ~picture report ->
         run_checkpoint setup ~log ~picture report plan))

let load_checked program ~plan_dir ids =
  let* plans = Plan_folder.load_all ~load:load_plan ~plan_dir ids in
  let* () = program.check_plans plans in
  Ok plans

let rec last_item = function
  | [] -> None
  | [ x ] -> Some x
  | _ :: rest -> last_item rest

let select_range ~plan_dir (f : unit Run_flags.flags) =
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

let run_plans (program : program) flags ~options ~policy plans daemons =
  let setup =
    {
      flags;
      options;
      daemons;
      initial_screen = program.initial_screen;
      run_action = program.run_action;
    }
  in
  Series_runner.run_testing ~policy ~now_ms:Run_record.now_ms ~log:print_endline
    ~entry_id:(fun (p : B.Plan.t) -> p.checkpoint.checkpoint_id)
    ~run_trial:(run_trial setup) ~trial_of plans

let run_series program ~program_fields ~options ~viewport plan_dir args =
  let* f = Run_flags.parse_no_game_flags args in
  let* () = Run_flags.require_testing_only ~game:"BDSP" f in
  let* range = select_range ~plan_dir f in
  let* backend = Run_flags.daemon_backend f Testing in
  let* () = Run_flags.require_switch ~game:"BDSP" backend in
  let* viewport = viewport in
  let* policy = Checkpoint_trials.policy ?runs:f.runs Testing in
  let* plans = load_checked program ~plan_dir range.selected in
  let info =
    Run_flags.run_info ~program:program_fields ~from_id:range.from_id
      ~to_id:range.to_id ~options f
  in
  Ok
    (Switch_series.run_series ~daemon:f.daemon ~runs_dir:f.runs_dir ~backend
       ~viewport ~program_flags:program.daemon_flags
       ~daemon_flags:f.daemon_flags ~port:f.port ~watch:f.watch
       ~close_game:f.close_game ~info ~checkpoints:range.selected
       (run_plans program f ~options ~policy plans))
