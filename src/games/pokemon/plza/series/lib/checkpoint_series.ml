open Engine_run
open Engine_series
open Live_run
module P = Plza_engine
module Attempts = Run_attempts
module Chain = Series_chain

let ( let* ) = Result.bind

type outcome = Attempts.outcome = Passed | Failed of Attempts.failure

type attempt =
  log:(string -> unit) ->
  picture:Wire.box ->
  reload:bool ->
  Watch_report.t ->
  P.Plan.t ->
  outcome

type program = {
  check_plans : P.Plan.t list -> (unit, string) result;
  with_end_place :
    next:P.Plan.t option -> P.Plan.t -> (P.Plan.t, string) result;
  daemon_flags : string list;
  initial_screen : P.Plan.t -> Switch.Initial_screen.expectation;
  attempt : attempt;
}

type setup = {
  flags : Flags.t;
  policy : Checkpoint_trials.policy;
  info : Run_record.info;
  daemons : Live_run.Series_daemons.t;
  initial_screen : P.Plan.t -> Switch.Initial_screen.expectation;
  attempt : attempt;
}

let keepawake_stick = [ "--keepawake-key"; "RStick" ]

let each_plan check plans =
  List.fold_left
    (fun acc plan -> Result.bind acc (fun () -> check plan))
    (Ok ()) plans

let no_end_place ~next:_ plan = Ok plan

let load_plan ~plan_dir id =
  P.Plan_decode.load (Plan_folder.plan_file ~plan_dir id)

let failed ?(repeats = false) ?(off_start = false) at reason =
  Failed { at; reason; repeats; off_start }

let of_runner ({ at; reason; repeats } : Daemon_run.failed) =
  failed ~repeats at reason

let check_initial_screen ~log ~picture ~already_at_start expectation =
  if not already_at_start then
    Switch.Initial_screen.check ~log ~picture expectation
  else (
    log
      "[Console] continuing from previous pass (skipping initial-screen check)";
    Ok ())

let guard_attempt ~end_failed body =
  match body () with
  | outcome -> outcome
  | exception (Effects.Disconnected _ as e) -> raise e
  | exception Effects.Stop_requested reason ->
      end_failed ();
      failed ~repeats:true "stopped" reason
  | exception e ->
      end_failed ();
      failed "raised" (Printexc.to_string e)

let run_guarded setup ~log ~picture ~reload ~already_at_start report plan =
  let end_failed () = Watch_report.end_run report ~passed:false in
  match
    check_initial_screen ~log ~picture ~already_at_start
      (setup.initial_screen plan)
  with
  | Error reason ->
      end_failed ();
      failed ~repeats:true "start" reason
  | Ok () ->
      guard_attempt ~end_failed (fun () ->
          setup.attempt ~log ~picture ~reload report plan)

let in_session setup ~log ~reload ~already_at_start record plan
    (backend : Wire.backend) =
  let picture = backend.viewport in
  let log = Watch_report.log log in
  let report = P.Plan_watch.create plan.P.Plan.checkpoint in
  let outcome =
    run_guarded setup ~log ~picture ~reload ~already_at_start report plan
  in
  (match outcome with
  | Failed _ -> Daemon_run.save_failure ~log record ~save_states:false
  | Passed -> ());
  outcome

let ending_of name outcome =
  let summary =
    match outcome with
    | Passed -> "PASS " ^ name
    | Failed { at; reason; _ } ->
        Printf.sprintf "FAIL %s at %s: %s" name at reason
  in
  let ending : Run_record.ending =
    match outcome with
    | Passed -> { result = "pass"; at = ""; reason = "" }
    | Failed { at; reason; _ } -> { result = "fail"; at; reason }
  in
  (summary, ending)

let run_name ~id ~n ~attempt =
  match attempt with
  | 1 -> Printf.sprintf "%s run %d" id n
  | a -> Printf.sprintf "%s run %d attempt %d" id n a

let run_in_folder setup plan n ~attempt ~reload ~already_at_start
    (run : Run_record.run) =
  let id = plan.P.Plan.checkpoint.checkpoint_id in
  let name = run_name ~id ~n ~attempt in
  let banner = "[Run] " ^ name ^ if reload then " (after a reload)" else "" in
  let live ~log (daemon : Daemon_process.t) =
    Daemon_run.run_live ~failed:of_runner ~dir:run.record.dir ~port:daemon.port
      (in_session setup ~log ~reload ~already_at_start run.record plan)
  in
  Series_daemons.run_in setup.daemons ~runs_dir:setup.flags.runs_dir
    ~failed:of_runner ~ending:(ending_of name) ~banner run ~n live

let run_attempt setup plan n ~attempt ~reload ~already_at_start =
  let id = plan.P.Plan.checkpoint.checkpoint_id in
  match
    Run_record.start ~runs_dir:setup.flags.runs_dir setup.info ~checkpoint:id
      ~mode:"testing"
  with
  | Error reason ->
      Failed { at = "run folder"; reason; repeats = true; off_start = false }
  | Ok run -> run_in_folder setup plan n ~attempt ~reload ~already_at_start run

let run setup (plan : P.Plan.t) (t : Chain.trial) ~reload =
  let id = plan.checkpoint.checkpoint_id in
  let one ~attempt ~reload =
    let already_at_start =
      Chain.trial_already_at_start t ~attempt && not reload
    in
    run_attempt setup plan t.number ~attempt ~reload ~already_at_start
  in
  Attempts.run
    ~has_start:(Option.is_some plan.checkpoint.start)
    ~retries:plan.retries ~reload_first:reload
    ~log:(fun line ->
      Printf.printf "[Checkpoints] %s run %d: %s\n%!" id t.number line)
    one

let reload_when_chained (plan : P.Plan.t) =
  List.assoc_opt "reload_when_chained" plan.execution = Some (`Bool true)

let run_trial setup plan (t : Chain.trial) =
  let reload =
    t.number > 1 || (t.continuing_from_pass && reload_when_chained plan)
  in
  Ok (run setup plan t ~reload)

let runs_of setup plan ~continuing_from_pass =
  let verdict, _ =
    Chain.run_trials setup.policy ~continuing_from_pass ~trial:Attempts.trial
      (run_trial setup plan)
  in
  let passed, line =
    Chain.verdict_outcome ~id:plan.checkpoint.checkpoint_id verdict
  in
  Option.iter print_endline line;
  passed

let rec next_id id = function
  | a :: (b :: _ as rest) -> if a = id then Some b else next_id id rest
  | [ _ ] | [] -> None

(* Each plan given its end place by the program, from the plan after it (the
   folder's next one after the last). *)
let with_ends program ~plan_dir ~all plans =
  List.fold_left
    (fun acc (plan : P.Plan.t) ->
      let* acc = acc in
      let* next =
        match next_id plan.checkpoint.checkpoint_id all with
        | None -> Ok None
        | Some n -> Result.map Option.some (load_plan ~plan_dir n)
      in
      let* plan = program.with_end_place ~next plan in
      Ok (acc @ [ plan ]))
    (Ok []) plans

(* Every plan of the series, loaded in order, then checked before the
   console moves, then given its end place. *)
let load_checked program ~plan_dir ~all ids =
  let* plans =
    List.fold_left
      (fun plans id ->
        let* plans = plans in
        let* plan = load_plan ~plan_dir id in
        Ok (plans @ [ plan ]))
      (Ok []) ids
  in
  let* () = program.check_plans plans in
  with_ends program ~plan_dir ~all plans

(* Each run's daemon: the program's viewport, its own flags, then the
   user's. *)
let daemons (f : Flags.t) backend ~viewport ~program_flags series =
  Series_daemons.create ~daemon:f.daemon ~backend ~port:f.port
    ~flags:
      (Daemon_process.viewport_args backend viewport
      @ program_flags @ f.daemon_flags)
    ~watch:
      (Watch_hub.for_runs_dir ~daemon:f.daemon ~runs_dir:f.runs_dir f.watch)
    series

let setup_of program (f : Flags.t) ~program_fields ~options ~from_id ~to_id ~ids
    ~backend ~viewport policy =
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
    policy;
    info;
    daemons =
      daemons f backend ~viewport ~program_flags:program.daemon_flags
        { info; mode; checkpoints = ids };
    initial_screen = program.initial_screen;
    attempt = program.attempt;
  }

let switch_only : Daemon_process.backend -> _ = function
  | Mgba _ -> Error "PLZA runs on the Switch only: --backend switch"
  | Switch _ -> Ok ()

(* The checkpoints from --from to --to, in run order. *)
let selected ~plan_dir (f : Flags.t) =
  let* from_id = Run_flags.required "--from" f.from_id in
  let* to_id = Run_flags.required "--to" f.to_id in
  let* ids = Plan_folder.checkpoint_ids plan_dir in
  let* from_id = Plan_folder.resolve ids from_id in
  let* to_id = Plan_folder.resolve ids to_id in
  let* selected, _ = Plan_folder.select ids ~from_id ~to_id in
  Ok (from_id, to_id, selected, ids)

let run_series program ~program_fields ~options ~viewport plan_dir args =
  let* f = Flags.parse args in
  let* () = Flags.takes f in
  let* from_id, to_id, ids, all = selected ~plan_dir f in
  let* backend = Run_flags.daemon_backend f Testing in
  let* () = switch_only backend in
  let* viewport = viewport in
  let* policy = Checkpoint_trials.policy ?runs:f.runs Testing in
  let* plans = load_checked program ~plan_dir ~all ids in
  let setup =
    setup_of program f ~program_fields ~options ~from_id ~to_id ~ids ~backend
      ~viewport policy
  in
  let passed =
    Chain.run_chain plans (fun item ->
        runs_of setup item.value ~continuing_from_pass:item.continuing_from_pass)
  in
  let code = if passed then 0 else 1 in
  Series_daemons.finished setup.daemons ~passed;
  let closed =
    Series_daemons.close_game_after_pass setup.daemons ~close_game:f.close_game
      ~passed ()
  in
  Ok (if code = 0 && not closed then 1 else code)
