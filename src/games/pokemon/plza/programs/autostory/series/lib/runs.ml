open Engine_run
module P = Plza_checkpoints
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

module Attempts = Story.Run_attempts

type outcome = Attempts.outcome = Passed | Failed of Attempts.failure

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

let failed ?(repeats = false) ?(off_start = false) at reason =
  Failed { at; reason; repeats; off_start }

let of_runner ({ at; reason; repeats } : Live_run.Daemon_run.failed) =
  failed ~repeats at reason

let reload_cause ~log ~picture () =
  Result.map_error
    (fun e -> Failure.cause "reload_failed" e)
    (Story.Game_reload.reload ~log ~picture)

let unreachable (plan : P.Plan.t) =
  failed ~repeats:true "start"
    (plan.checkpoint.checkpoint_id
   ^ " starts on a screen made by hand, which no reload reaches: put the \
      console there and run it again")

let back_to_autosave ~log ~picture =
  log "[Console] back to the latest autosave";
  Result.map_error
    (fun e -> failed ~repeats:true "reload" e)
    (Story.Game_reload.reload ~log ~picture)

(* Back to the latest autosave before a run that is not the series' first. *)
let start ~log ~picture ~reload (plan : P.Plan.t) =
  match (reload, plan.checkpoint.start) with
  | false, _ -> Ok ()
  | true, None -> Error (unreachable plan)
  | true, Some _ -> back_to_autosave ~log ~picture

(* 01.00a's new game, with PLZA's HOME title uploaded for its launch; the
   choices it plays (the program's options over the plan's) in the log. *)
let new_game ~log ~picture choices =
  log ("[Console] new game: " ^ Story.New_game_options.describe choices);
  match Templates.upload_home_title () with
  | Error e -> Error (Failure.cause ~repeats:true "assets" e)
  | Ok home_title ->
      Story.Live_intro_screen.run ~picture ~log ~home_title choices

let run_checkpoint ~options ~log ~picture ~reload report (plan : P.Plan.t) =
  let* () = start ~log ~picture ~reload plan in
  let steps =
    Story.Live_story_screen.game_steps ~picture ~log ~log_detail:log
  in
  (* A console idle between runs dims its screen; nothing reads on it. *)
  Plza_story.Screen_wake.run steps;
  let id = plan.checkpoint.checkpoint_id in
  let* () =
    Result.map_error
      (Attempts.of_cause ~at:"start")
      (Story.Start_signature.check steps ~checkpoint_id:id plan.execution)
  in
  let game =
    Story.Story_game.make ~options steps ~checkpoint:plan.checkpoint
      ~new_game:(new_game ~log ~picture)
      ~reload:(reload_cause ~log ~picture)
  in
  let end_check () =
    Story.Start_signature.check_end steps ~checkpoint_id:id plan.execution
  in
  Result.map_error Attempts.of_failure
    (Story.Story_game.run_watched ~end_check ~mode:"testing" report game
       plan.checkpoint)

(* The run fails on the page when it stops before its runner ended it. *)
let with_assets ~options ~log ~picture ~reload report plan assets =
  match
    Effects.with_probes (Story.Live_story_screen.probes ~picture ~assets)
      (fun () -> run_checkpoint ~options ~log ~picture ~reload report plan)
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

let in_session ~options ~log ~reload record plan (backend : Wire.backend) =
  let picture = backend.viewport in
  let log = Watch_report.log log in
  let report = P.Plan_watch.create plan.P.Plan.checkpoint in
  let outcome =
    match Templates.upload () with
    | Error e -> failed ~repeats:true "assets" e
    | Ok assets -> with_assets ~options ~log ~picture ~reload report plan assets
  in
  (match outcome with Failed _ -> save_failure record | Passed -> ());
  outcome

(* Any exception Daemon_run.in_session passes on fails the run here, so the
   story log, the run record and the watch run still close. *)
let live ~options ~log ~reload record plan (daemon : Live_run.Daemon_process.t)
    =
  match
    Live_run.Daemon_run.in_session ~failed:of_runner ~dir:record.Run_record.dir
      (fun () ->
        Live.run_with_backend ~port:daemon.port
          (in_session ~options ~log ~reload record plan))
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

(* "03.08 run 1", with " attempt 2" after the first. *)
let run_name id n = function
  | 1 -> Printf.sprintf "%s run %d" id n
  | a -> Printf.sprintf "%s run %d attempt %d" id n a

let summary name = function
  | Passed -> "PASS " ^ name
  | Failed { at; reason; _ } ->
      Printf.sprintf "FAIL %s at %s: %s" name at reason

(* Attempt [attempt] of run [n] of [plan]; [reload]: back to the latest
   autosave first. *)
let run_attempt setup plan n ~attempt ~reload =
  let id = plan.P.Plan.checkpoint.checkpoint_id in
  let run =
    Run_record.start ~runs_dir:setup.flags.runs_dir setup.info ~checkpoint:id
      ~mode:"testing"
  in
  let name = run_name id n attempt in
  let log, close = Run_record.story_log run.record in
  log ("[Run] " ^ name ^ if reload then " (after a reload)" else "");
  let outcome =
    with_daemon setup run.record id
      (live ~options:setup.flags.game ~log ~reload run.record plan)
  in
  close ();
  let ending : Run_record.ending =
    match outcome with
    | Passed -> { result = "pass"; at = ""; reason = "" }
    | Failed { at; reason; _ } -> { result = "fail"; at; reason }
  in
  Live_run.Daemon_run.finish ~runs_dir:setup.flags.runs_dir run
    ~summary:(summary name outcome) ending;
  outcome

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
   in the series (the fork's "reload_when_chained", 03.04's: its walk starts
   from the autosave's spot, not where 03.03c's scene leaves the player). *)
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
         (fun n -> run setup plan n ~reload:(reload n)))
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

(* Every plan of the series, loaded and checked (Series_check) before the
   console moves. *)
let load_checked ~plan_dir ~options ids =
  let* plans = Series_check.all_ok (List.map (load_plan ~plan_dir) ids) in
  let* () = Series_check.check ~options plans in
  Ok plans

let checkpoint_order = String.compare

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

(* The checkpoints from --from to --to, in run order. *)
let selected ~plan_dir (f : Flags.t) =
  let* from_id = Checkpoints_flags.required "--from" f.from_id in
  let* to_id = Checkpoints_flags.required "--to" f.to_id in
  let* ids =
    Engine_series.Plan_folder.checkpoint_ids ~compare:checkpoint_order plan_dir
  in
  let* ids, _ = Engine_series.Plan_folder.select ids ~from_id ~to_id in
  Ok (from_id, to_id, ids)

let run_series ~program ~viewport plan_dir args =
  let* f = Flags.parse args in
  let* () = Flags.takes f in
  let* from_id, to_id, ids = selected ~plan_dir f in
  let* backend = Checkpoints_flags.daemon_backend f Checkpoint_trials.Testing in
  let* () = switch_only backend in
  let* viewport = viewport in
  let* policy =
    Checkpoint_trials.policy ?runs:f.runs Checkpoint_trials.Testing
  in
  let* plans = load_checked ~plan_dir ~options:f.game ids in
  chain
    (setup_of f ~program ~from_id ~to_id ~backend ~viewport policy)
    ~chained:false plans
