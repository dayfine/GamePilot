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
  flags : unit Run_flags.flags;
  daemons : Series_daemons.t;
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

let load_title ~plan_dir id =
  Result.map
    (fun (p : P.Plan.t) -> (p.checkpoint.checkpoint_id, p.checkpoint.title))
    (load_plan ~plan_dir id)

let failed ?(repeats = false) ?(off_start = false) at reason =
  Failed { at; reason; repeats; off_start }

let result_of = function
  | Passed -> Ok ()
  | Failed { at; reason; _ } -> Error (at, reason)

let run_attempt setup plan n ~attempt ~reload ~already_at_start =
  let checkpoint_id = plan.P.Plan.checkpoint.checkpoint_id in
  let banner_suffix = if reload then " (after a reload)" else "" in
  Switch_series.run_attempt ~daemons:setup.daemons
    ~runs_dir:setup.flags.runs_dir ~checkpoint_id ~n ~attempt ~banner_suffix
    ~already_at_start
    ~expectation:(setup.initial_screen plan)
    ~create_report:(fun () -> P.Plan_watch.create plan.P.Plan.checkpoint)
    ~failed:(fun ~repeats ~at ~reason -> failed ~repeats at reason)
    ~result_of
    (fun ~log ~picture report ->
      setup.attempt ~log ~picture ~reload report plan)

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
  let* plans = Plan_folder.load_all ~load:load_plan ~plan_dir ids in
  let* () = program.check_plans plans in
  with_ends program ~plan_dir ~all plans

(* The checkpoints from --from to --to, in run order. *)
let selected ~plan_dir (f : unit Run_flags.flags) =
  let* from_id = Run_flags.required "--from" f.from_id in
  let* to_id = Run_flags.required "--to" f.to_id in
  Plan_folder.select_range ~plan_dir ~from_id ~to_id

let run_plans (program : program) flags ~policy plans daemons =
  let setup =
    {
      flags;
      daemons;
      initial_screen = program.initial_screen;
      attempt = program.attempt;
    }
  in
  Series_runner.run_testing ~policy ~now_ms:Run_record.now_ms ~log:print_endline
    ~entry_id:(fun (p : P.Plan.t) -> p.checkpoint.checkpoint_id)
    ~run_trial:(run_trial setup) ~trial_of:Attempts.trial plans

let run_series program ~program_fields ~options ~viewport plan_dir args =
  let* f = Run_flags.parse_no_game_flags args in
  let* () = Run_flags.require_testing_only ~game:"PLZA" f in
  let* range = selected ~plan_dir f in
  let* backend = Run_flags.daemon_backend f Testing in
  let* () = Run_flags.require_switch ~game:"PLZA" backend in
  let* viewport = viewport in
  let* policy = Checkpoint_trials.policy ?runs:f.runs Testing in
  let* plans = load_checked program ~plan_dir ~all:range.all range.selected in
  let info =
    Run_flags.run_info ~program:program_fields ~from_id:range.from_id
      ~to_id:range.to_id ~options f
  in
  Ok
    (Switch_series.run_series ~daemon:f.daemon ~runs_dir:f.runs_dir ~backend
       ~viewport ~program_flags:program.daemon_flags
       ~daemon_flags:f.daemon_flags ~port:f.port ~watch:f.watch
       ~close_game:f.close_game ~info ~checkpoints:range.selected
       (run_plans program f ~policy plans))
