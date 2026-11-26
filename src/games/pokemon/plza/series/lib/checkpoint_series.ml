open Engine_run
module P = Plza_engine
module Attempts = Run_attempts

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
  attempt : attempt;
}

type setup = {
  flags : Flags.t;
  policy : Checkpoint_trials.policy;
  info : Run_record.info;
  daemons : Live_run.Series_daemons.t;
  attempt : attempt;
}

let keepawake_stick = [ "--keepawake-key"; "RStick" ]

let each_plan check plans =
  List.fold_left
    (fun acc plan -> Result.bind acc (fun () -> check plan))
    (Ok ()) plans

let no_end_place ~next:_ plan = Ok plan

let load_plan ~plan_dir id =
  P.Plan_decode.load (Engine_series.Plan_folder.plan_file ~plan_dir id)

let failed ?(repeats = false) ?(off_start = false) at reason =
  Failed { at; reason; repeats; off_start }

let of_runner ({ at; reason; repeats } : Live_run.Daemon_run.failed) =
  failed ~repeats at reason

(* The run fails on the page when it stops before its runner ended it. *)
let watched attempt ~log ~picture ~reload report plan =
  match attempt ~log ~picture ~reload report plan with
  | outcome -> outcome
  | exception Effects.Stop_requested why ->
      Watch_report.end_run report ~passed:false;
      failed ~repeats:true "stopped" why
  | exception (Effects.Disconnected _ as e) -> raise e
  | exception e ->
      (* Any other exception ends the watch run here; the run fails as
         [live] fails one. *)
      Watch_report.end_run report ~passed:false;
      failed "raised" (Printexc.to_string e)

let in_session attempt ~log ~reload record plan (backend : Wire.backend) =
  let picture = backend.viewport in
  let log = Watch_report.log log in
  let report = P.Plan_watch.create plan.P.Plan.checkpoint in
  let outcome = watched attempt ~log ~picture ~reload report plan in
  (match outcome with
  | Failed _ -> Live_run.Daemon_run.save_failure ~log record ~save_states:false
  | Passed -> ());
  outcome

(* Any exception Daemon_run.in_session passes on fails the run here, so the
   story log, the run record and the watch run still close. *)
let live attempt ~log ~reload record plan (daemon : Live_run.Daemon_process.t) =
  match
    Live_run.Daemon_run.in_session ~failed:of_runner ~dir:record.Run_record.dir
      (fun () ->
        Live.run_with_backend ~port:daemon.port
          (in_session attempt ~log ~reload record plan))
  with
  | outcome -> outcome
  | exception e -> failed "raised" (Printexc.to_string e)

(* "03.07 run 1", with " attempt 2" after the first. *)
let run_name id n = function
  | 1 -> Printf.sprintf "%s run %d" id n
  | a -> Printf.sprintf "%s run %d attempt %d" id n a

let summary name = function
  | Passed -> "PASS " ^ name
  | Failed { at; reason; _ } ->
      Printf.sprintf "FAIL %s at %s: %s" name at reason

(* Attempt [attempt] of run [n] of [plan] in its folder [run]; [reload]: back
   to the latest autosave first. *)
let run_in setup plan n ~attempt ~reload (run : Run_record.run) =
  let id = plan.P.Plan.checkpoint.checkpoint_id in
  let name = run_name id n attempt in
  let log, close = Run_record.story_log run.record in
  log ("[Run] " ^ name ^ if reload then " (after a reload)" else "");
  let outcome =
    Live_run.Series_daemons.with_daemon setup.daemons ~failed:of_runner run ~n
      (live setup.attempt ~log ~reload run.record plan)
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

(* {!run_in} in a new run folder; a folder that cannot be made fails the
   attempt, as a failure that repeats. *)
let run_attempt setup plan n ~attempt ~reload =
  let id = plan.P.Plan.checkpoint.checkpoint_id in
  match
    Run_record.start ~runs_dir:setup.flags.runs_dir setup.info ~checkpoint:id
      ~mode:"testing"
  with
  | Ok run -> run_in setup plan n ~attempt ~reload run
  | Error reason ->
      Failed { at = "run folder"; reason; repeats = true; off_start = false }

(* Run [n] of [plan]: attempts until one passes or the run fails
   (Run_attempts: a reload when off its start, and the plan's retries).
   [reload]: its first attempt goes back to the latest autosave. *)
let run setup (plan : P.Plan.t) n ~reload =
  let id = plan.checkpoint.checkpoint_id in
  Attempts.run
    ~has_start:(Option.is_some plan.checkpoint.start)
    ~retries:plan.retries ~reload_first:reload
    ~log:(fun line -> Printf.printf "[Checkpoints] %s run %d: %s\n%!" id n line)
    (run_attempt setup plan n)

(* The plan's execution asks for a reload when it follows another checkpoint
   in the series (the fork's "reload_when_chained", 03.07's: its walk starts
   from the autosave's spot, not where 03.06's scene leaves the player). *)
let reload_when_chained (plan : P.Plan.t) =
  List.assoc_opt "reload_when_chained" plan.execution = Some (`Bool true)

(* Runs [plan] until the policy decides; whether it passed. Its first run
   starts where the console is: the series' start, put there by hand, or
   where the checkpoint before it ended (the fork chains 01.03 into 02.01
   with no reload either; a reload there cost 40 s and turned the camera),
   unless the plan reloads when chained. [chained]: a checkpoint ran before it
   in the series. *)
let runs_of setup plan ~chained =
  let reload n = n > 1 || (chained && reload_when_chained plan) in
  match
    fst
      (Checkpoint_trials.until_decided setup.policy ~trial:Attempts.trial
         (fun n -> Ok (run setup plan n ~reload:(reload n))))
  with
  | Checkpoint_trials.Run_again -> false
  | Checkpoint_passed { passes; runs } ->
      Printf.printf "[Checkpoints] %s: passed (%d of %d runs)\n%!"
        plan.checkpoint.checkpoint_id passes runs;
      true
  | Stopped why ->
      Printf.printf "[Checkpoints] %s: stopped: %s\n%!"
        plan.checkpoint.checkpoint_id why;
      false

let rec chain setup ~chained = function
  | [] -> Ok 0
  | plan :: rest ->
      if runs_of setup plan ~chained then chain setup ~chained:true rest
      else Ok 1

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
  Live_run.Series_daemons.create ~daemon:f.daemon ~backend ~port:f.port
    ~flags:
      (Live_run.Daemon_process.viewport_args backend viewport
      @ program_flags @ f.daemon_flags)
    ~watch:
      (Live_run.Watch_hub.for_runs_dir ~daemon:f.daemon ~runs_dir:f.runs_dir
         f.watch)
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
    attempt = program.attempt;
  }

let switch_only : Live_run.Daemon_process.backend -> _ = function
  | Mgba _ -> Error "PLZA runs on the Switch only: --backend switch"
  | Switch _ -> Ok ()

(* The checkpoints from --from to --to, in run order. *)
let selected ~plan_dir (f : Flags.t) =
  let* from_id = Run_flags.required "--from" f.from_id in
  let* to_id = Run_flags.required "--to" f.to_id in
  let* ids = Engine_series.Plan_folder.checkpoint_ids plan_dir in
  let* from_id = Engine_series.Plan_folder.resolve ids from_id in
  let* to_id = Engine_series.Plan_folder.resolve ids to_id in
  let* selected, _ = Engine_series.Plan_folder.select ids ~from_id ~to_id in
  Ok (from_id, to_id, selected, ids)

let run_series program ~program_fields ~options ~viewport plan_dir args =
  let* f = Flags.parse args in
  let* () = Flags.takes f in
  let* from_id, to_id, ids, all = selected ~plan_dir f in
  let* backend = Run_flags.daemon_backend f Checkpoint_trials.Testing in
  let* () = switch_only backend in
  let* viewport = viewport in
  let* policy =
    Checkpoint_trials.policy ?runs:f.runs Checkpoint_trials.Testing
  in
  let* plans = load_checked program ~plan_dir ~all ids in
  let setup =
    setup_of program f ~program_fields ~options ~from_id ~to_id ~ids ~backend
      ~viewport policy
  in
  let* code = chain setup ~chained:false plans in
  Live_run.Series_daemons.finished setup.daemons ~passed:(code = 0);
  Ok code
