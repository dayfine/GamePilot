open Engine_run
module P = Plza_engine
module Story = Plza_autostory

let ( let* ) = Result.bind

(* The daemon's keep-awake presses B after 180 s idle on the Switch; B backs
   out of PLZA's new-game menus (console B, 2026-11-25), so PLZA's daemons
   nudge the right stick instead, which only turns the camera in the field and
   does nothing in a dialogue, a menu or a battle (up then down, so the
   camera's heading never moves: walk legs are aimed from it). Off, an idle
   console dimmed its screen, which reads as nothing (01.03's run 2). A
   --keepawake-key given on the command line comes after, and the daemon takes
   the last. *)
let keepawake_stick = [ "--keepawake-key"; "RStick" ]

type failure = { at : string; reason : string; repeats : bool }
type outcome = Passed | Failed of failure

type setup = {
  flags : Flags.t;
  backend : Live_run.Daemon_process.backend;
  policy : Checkpoint_trials.policy;
  info : Run_record.info;
  daemon_flags : string list;
  watch : Live_run.Daemon_process.watch option;
}

let load_plan ~plan_dir id =
  let plan_suffix = Engine_series.Plan_folder.plan_suffix in
  match
    Yojson.Safe.from_file (Engine_series.Plan_folder.plan_file ~plan_dir id)
  with
  | json -> P.Plan_decode.decode ~source:(id ^ plan_suffix) json
  | exception Sys_error e -> Error e
  | exception Yojson.Json_error e -> Error (id ^ ": " ^ e)

let failed ?(repeats = false) at reason = Failed { at; reason; repeats }

let of_runner ({ at; reason; repeats } : Live_run.Daemon_run.failed) =
  failed ~repeats at reason

(* The runner's failure at "#<n> <event>". *)
let of_failure (f : P.Failure.t) =
  failed ~repeats:(P.Failure.repeats f)
    (Printf.sprintf "#%d %s" (f.event_index + 1) f.event_id)
    (P.Failure.reason_to_string f.reason)

let trial = function
  | Passed -> Checkpoint_trials.Passed
  | Failed { at; repeats; _ } -> Checkpoint_trials.Failed { at; repeats }

let no_reload () =
  Error
    (Failure.cause ~repeats:true "no_reload"
       "PLZA's skeleton cannot go back to the latest autosave yet")

let run_checkpoint ~log ~picture report (plan : P.Plan.t) =
  let steps =
    Story.Live_story_screen.game_steps ~picture ~log ~log_detail:log
  in
  let game =
    Story.Story_game.make steps ~checkpoint:plan.checkpoint ~reload:no_reload
  in
  Result.map_error of_failure
    (Story.Story_game.run_watched ~mode:"testing" report game plan.checkpoint)

(* The run fails on the page when it stops before its runner ended it. *)
let with_assets ~log ~picture report plan assets =
  match
    Effects.with_probes (Story.Live_story_screen.probes ~picture ~assets)
      (fun () -> run_checkpoint ~log ~picture report plan)
  with
  | Ok () -> Passed
  | Error f -> f
  | exception Effects.Stop_requested why ->
      Watch_report.end_run report ~passed:false;
      failed ~repeats:true "stopped" why
  | exception (Effects.Disconnected _ as e) -> raise e
  | exception e ->
      (* Any other exception ends the watch run here; the run fails as
         [live] fails one. *)
      Watch_report.end_run report ~passed:false;
      failed "raised" (Printexc.to_string e)

(* The frame a failed run ended on; a refusal is skipped. *)
let save_failure record =
  match Effects.save_frame (Run_record.path record "failure.png") with
  | (_ : int) -> ()
  | exception Effects.Rpc_error _ -> ()

let in_session ~log record plan (backend : Wire.backend) =
  let picture = backend.viewport in
  let log = Watch_report.log log in
  let report = P.Plan_watch.create plan.P.Plan.checkpoint in
  let outcome =
    match Templates.upload () with
    | Error e -> failed ~repeats:true "assets" e
    | Ok assets -> with_assets ~log ~picture report plan assets
  in
  (match outcome with Failed _ -> save_failure record | Passed -> ());
  outcome

(* Any exception Daemon_run.in_session passes on fails the run here, so the
   story log, the run record and the watch run still close. *)
let live ~log record plan (daemon : Live_run.Daemon_process.t) =
  match
    Live_run.Daemon_run.in_session ~failed:of_runner ~dir:record.Run_record.dir
      (fun () ->
        Live.run_with_backend ~port:daemon.port (in_session ~log record plan))
  with
  | outcome -> outcome
  | exception e -> failed "raised" (Printexc.to_string e)

let print_page setup (daemon : Live_run.Daemon_process.t) =
  match (setup.watch, daemon.watch_port) with
  | Some w, Some port ->
      Live_run.Watch_urls.print ~listen:w.listen ~token:w.token ~port
  | _ -> ()

let with_daemon setup record id body =
  Live_run.Daemon_run.with_daemon ~failed:of_runner
    (Live_run.Daemon_process.start ?watch:setup.watch ~flags:setup.daemon_flags
       ~daemon:setup.flags.daemon ~backend:setup.backend ~port:0
       ~wire_log:(Run_record.path record "wire.jsonl")
       ~out_file:(Run_record.path record "daemon.out")
       ~checkpoint:id ())
    (fun daemon ->
      print_page setup daemon;
      body daemon)

let run_name id n = Printf.sprintf "%s run %d" id n

let summary name = function
  | Passed -> "PASS " ^ name
  | Failed { at; reason; _ } ->
      Printf.sprintf "FAIL %s at %s: %s" name at reason

(* Run [n] of [plan] in its folder [run]. *)
let run_in setup plan n (run : Run_record.run) =
  let id = plan.P.Plan.checkpoint.checkpoint_id in
  let name = run_name id n in
  let log, close = Run_record.story_log run.record in
  log ("[Run] " ^ name);
  let outcome = with_daemon setup run.record id (live ~log run.record plan) in
  close ();
  let ending : Run_record.ending =
    match outcome with
    | Passed -> { result = "pass"; at = ""; reason = "" }
    | Failed { at; reason; _ } -> { result = "fail"; at; reason }
  in
  Live_run.Daemon_run.finish ~runs_dir:setup.flags.runs_dir run
    ~summary:(summary name outcome) ending;
  outcome

(* Run [n] of [plan] in a new run folder; a folder that cannot be made fails
   the run, as a failure that repeats. *)
let run setup (plan : P.Plan.t) n =
  let id = plan.checkpoint.checkpoint_id in
  match
    Run_record.start ~runs_dir:setup.flags.runs_dir setup.info ~checkpoint:id
      ~mode:"testing"
  with
  | Ok run -> run_in setup plan n run
  | Error reason -> failed ~repeats:true "run folder" reason

(* Runs [plan] until the policy decides; whether it passed. Its run starts
   where the console is: the series' start, put there by hand, or where the
   checkpoint before it ended. *)
let runs_of setup plan =
  match
    fst
      (Checkpoint_trials.until_decided setup.policy ~trial (fun n ->
           Ok (run setup plan n)))
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

let rec chain setup = function
  | [] -> Ok 0
  | plan :: rest -> if runs_of setup plan then chain setup rest else Ok 1

(* Every plan of the series, loaded before the console moves. *)
let load_all ~plan_dir ids =
  List.fold_left
    (fun plans id ->
      let* plans = plans in
      let* plan = load_plan ~plan_dir id in
      Ok (plans @ [ plan ]))
    (Ok []) ids

let setup_of (f : Flags.t) ~program ~from_id ~to_id ~backend ~viewport policy =
  {
    flags = f;
    backend;
    policy;
    info = { kind = Checkpoints; program; from_id; to_id; backend = f.backend };
    daemon_flags =
      Live_run.Daemon_process.viewport_args backend viewport
      @ keepawake_stick @ f.daemon_flags;
    watch =
      Live_run.Watch_hub.for_runs_dir ~daemon:f.daemon ~runs_dir:f.runs_dir
        f.watch;
  }

let switch_only : Live_run.Daemon_process.backend -> _ = function
  | Mgba _ -> Error "PLZA runs on the Switch only: --backend switch"
  | Switch _ -> Ok ()

(* A second run of a checkpoint would start where the first ended: no reload
   puts it back yet. *)
let one_run (policy : Checkpoint_trials.policy) =
  if policy.runs > 1 then
    Error "PLZA runs each checkpoint once for now: no reload between runs"
  else Ok ()

(* The checkpoints from --from to --to, in run order. *)
let selected ~plan_dir (f : Flags.t) =
  let* from_id = Run_flags.required "--from" f.from_id in
  let* to_id = Run_flags.required "--to" f.to_id in
  let* ids = Engine_series.Plan_folder.checkpoint_ids plan_dir in
  let* ids, _ = Engine_series.Plan_folder.select ids ~from_id ~to_id in
  Ok (from_id, to_id, ids)

let run_series ~program ~viewport plan_dir args =
  let* f = Flags.parse args in
  let* () = Flags.takes f in
  let* from_id, to_id, ids = selected ~plan_dir f in
  let* backend = Run_flags.daemon_backend f Checkpoint_trials.Testing in
  let* () = switch_only backend in
  let* viewport = viewport in
  let* policy =
    Checkpoint_trials.policy ?runs:f.runs Checkpoint_trials.Testing
  in
  let* () = one_run policy in
  let* plans = load_all ~plan_dir ids in
  chain (setup_of f ~program ~from_id ~to_id ~backend ~viewport policy) plans
