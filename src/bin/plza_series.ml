(* gamepilot checkpoints --program plza.autostory --from ID --to ID
     --mode testing --backend switch --serial PORT --capture DEVICE
     [--runs N] [--watch] [--runs-dir DIR] [--daemon PATH]

   PLZA's checkpoints on the Switch (Plza_autostory.Story_game through the
   engine, Plza_checkpoints.Runner): each run its own daemon (the program's
   viewport, native) and run folder, as Checkpoint_live_run for FireRed, but
   without save states, a start check or an in-game save: PLZA saves by
   autosave. The series' first run starts where the console is, put there by
   hand (01.00b on the new game's Confirm Choices, 01.01 on the platform);
   every later run of the same checkpoint first goes back to the latest
   autosave (Plza_autostory.Game_reload), which 01.00b cannot (its start is
   no save): its second run is refused. A passing checkpoint hands the
   console to the next one as it ends. Its daemons run with keep-awake off
   (keepawake_off). The watch page shows each run's plan, its events moving
   with the runner (Story_game.run_watched), and the run. *)

open Engine_run
module P = Plza_checkpoints
module Story = Plza_autostory
module Assets = Plza_readers.Blob_assets

let ( let* ) = Result.bind

(* The daemon's keep-awake presses B after 180 s idle on the Switch; B backs
   out of PLZA's new-game menus (console B, 2026-11-25), so PLZA's daemons run
   without it. A --keepawake given on the command line comes after, and the
   daemon takes the last. *)
let keepawake_off = [ "--keepawake"; "0" ]

type outcome =
  | Passed
  | Failed of { at : string; reason : string; repeats : bool }

type setup = {
  flags : Checkpoints_flags.flags;
  backend : Daemon_process.backend;
  policy : Checkpoint_trials.policy;
  info : Run_record.info;
  daemon_flags : string list;
  watch : Daemon_process.watch option;
}

let load_plan ~plan_dir id =
  match Yojson.Safe.from_file (Plan_dir.plan_file ~plan_dir id) with
  | json -> P.Plan_decode.decode ~source:(id ^ Plan_dir.plan_suffix) json
  | exception Sys_error e -> Error e
  | exception Yojson.Json_error e -> Error (id ^ ": " ^ e)

let read_file path =
  match In_channel.with_open_bin path In_channel.input_all with
  | text -> Ok text
  | exception Sys_error e -> Error e

let upload dir name =
  Result.map Effects.upload_template (read_file (Filename.concat dir name))

let upload_from dir =
  let up = upload dir and f = Assets.file_names in
  let* dialog_white_arrow = up f.dialog_white_arrow in
  let* dialog_black_arrow = up f.dialog_black_arrow in
  let* dialog_teal_arrow = up f.dialog_teal_arrow in
  let* choice_arrow = up f.choice_arrow in
  let* advance_chevron_shape = up f.advance_chevron_shape in
  let* button_a = up f.button_a in
  Ok
    {
      Assets.dialog_white_arrow;
      dialog_black_arrow;
      dialog_teal_arrow;
      choice_arrow;
      advance_chevron_shape;
      button_a;
    }

(* Each template, uploaded to the daemon: its hash. *)
let upload_assets () =
  match Program_registry.locate Assets.folder with
  | None -> Error (Assets.folder ^ " not found from here: run in the repo")
  | Some dir -> upload_from dir

let failed ?(repeats = false) at reason = Failed { at; reason; repeats }

let of_failure (f : P.Failure.t) =
  failed ~repeats:(P.Failure.repeats f)
    (Printf.sprintf "#%d %s" (f.event_index + 1) f.event_id)
    (P.Failure.reason_to_string f.reason)

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

let run_checkpoint ~log ~picture ~reload report (plan : P.Plan.t) =
  let* () = start ~log ~picture ~reload plan in
  let steps =
    Story.Live_story_screen.game_steps ~picture ~log ~log_detail:log
  in
  let game =
    Story.Story_game.make steps ~checkpoint_id:plan.checkpoint.checkpoint_id
      ~reload:(reload_cause ~log ~picture)
  in
  Result.map_error of_failure
    (Story.Story_game.run_watched ~mode:"testing" report game plan.checkpoint)

(* The run fails on the page when it stops before its runner ended it. *)
let with_assets ~log ~picture ~reload report plan assets =
  match
    Effects.with_probes (Story.Live_story_screen.probes ~picture ~assets)
      (fun () -> run_checkpoint ~log ~picture ~reload report plan)
  with
  | Ok () -> Passed
  | Error f -> f
  | exception Effects.Stop_requested why ->
      Watch_report.end_run report ~passed:false;
      failed ~repeats:true "stopped" why

(* The frame a failed run ended on; a refusal is skipped. *)
let save_failure record =
  match Effects.save_frame (Run_record.path record "failure.png") with
  | (_ : int) -> ()
  | exception Effects.Rpc_error _ -> ()

let in_session ~log ~reload record plan (backend : Wire.backend) =
  let picture = backend.viewport in
  let log = Watch_report.log log in
  let report = P.Plan_watch.create plan.P.Plan.checkpoint in
  let outcome =
    match upload_assets () with
    | Error e -> failed ~repeats:true "assets" e
    | Ok assets -> with_assets ~log ~picture ~reload report plan assets
  in
  (match outcome with Failed _ -> save_failure record | Passed -> ());
  outcome

let live ~log ~reload record plan (daemon : Daemon_process.t) =
  match
    Effects.with_run_folder record.Run_record.dir (fun () ->
        Live.run_with_backend ~port:daemon.port
          (in_session ~log ~reload record plan))
  with
  | outcome -> outcome
  | exception Effects.Disconnected e -> failed "session" ("disconnected: " ^ e)
  | exception Unix.Unix_error (e, f, _) ->
      failed ~repeats:true "session" (f ^ ": " ^ Unix.error_message e)

let with_daemon setup record id body =
  match
    Daemon_process.start ?watch:setup.watch ~flags:setup.daemon_flags
      ~daemon:setup.flags.daemon ~backend:setup.backend ~port:0
      ~wire_log:(Run_record.path record "wire.jsonl")
      ~out_file:(Run_record.path record "daemon.out")
      ~checkpoint:id ()
  with
  | Error reason -> failed ~repeats:true "daemon" reason
  | Ok daemon ->
      (match (setup.watch, daemon.watch_port) with
      | Some w, Some port ->
          Watch_urls.print ~listen:w.listen ~token:w.token ~port
      | _ -> ());
      Fun.protect
        ~finally:(fun () -> Daemon_process.stop daemon)
        (fun () -> body daemon)

let summary id n = function
  | Passed -> Printf.sprintf "PASS %s run %d" id n
  | Failed { at; reason; _ } ->
      Printf.sprintf "FAIL %s run %d at %s: %s" id n at reason

(* Run [n] of [plan]; [reload] for any run but the series' first. *)
let run setup plan n ~reload =
  let id = plan.P.Plan.checkpoint.checkpoint_id in
  let run =
    Run_record.start ~runs_dir:setup.flags.runs_dir setup.info ~checkpoint:id
      ~mode:"testing"
  in
  let log, close = Run_record.story_log run.record in
  log
    (Printf.sprintf "[Run] %s run %d%s" id n
       (if reload then " (after a reload)" else ""));
  let outcome =
    with_daemon setup run.record id (live ~log ~reload run.record plan)
  in
  close ();
  let line = summary id n outcome in
  print_endline ("[Run] " ^ run.record.dir ^ ": " ^ line);
  let ending : Run_record.ending =
    match outcome with
    | Passed -> { result = "pass"; at = ""; reason = "" }
    | Failed { at; reason; _ } -> { result = "fail"; at; reason }
  in
  Run_record.finish ~runs_dir:setup.flags.runs_dir run ~summary:line ending;
  outcome

let trial = function
  | Passed -> Checkpoint_trials.Passed
  | Failed { at; repeats; _ } -> Checkpoint_trials.Failed { at; repeats }

(* Runs [plan] until the policy decides; whether it passed. [first]: the
   series has run nothing yet. *)
let rec runs_of setup plan ~first done_ =
  match Checkpoint_trials.verdict setup.policy (List.map trial done_) with
  | Checkpoint_trials.Run_again ->
      let reload = not (first && done_ = []) in
      let outcome = run setup plan (List.length done_ + 1) ~reload in
      runs_of setup plan ~first (done_ @ [ outcome ])
  | Checkpoint_passed { passes; runs } ->
      Printf.printf "[Checkpoints] %s: passed (%d of %d runs)\n%!"
        plan.checkpoint.checkpoint_id passes runs;
      true
  | Stopped why ->
      Printf.printf "[Checkpoints] %s: stopped: %s\n%!"
        plan.checkpoint.checkpoint_id why;
      false

let rec chain ~plan_dir setup ~first = function
  | [] -> Ok 0
  | id :: rest ->
      let* plan = load_plan ~plan_dir id in
      if runs_of setup plan ~first [] then
        chain ~plan_dir setup ~first:false rest
      else Ok 1

let run_series ~plan_dir (f : Checkpoints_flags.flags) ~backend ~viewport =
  let* from_id = Checkpoints_flags.required "--from" f.from_id in
  let* to_id = Checkpoints_flags.required "--to" f.to_id in
  let* policy =
    Checkpoint_trials.policy ?runs:f.runs Checkpoint_trials.Testing
  in
  let* ids = Plan_dir.checkpoint_ids plan_dir in
  let* selected, _ = Plan_dir.select ids ~from_id ~to_id in
  let program =
    Attached_run.program_fields (Program_registry.of_plan_dir plan_dir)
  in
  let setup =
    {
      flags = f;
      backend;
      policy;
      info =
        { kind = Checkpoints; program; from_id; to_id; backend = f.backend };
      daemon_flags =
        Daemon_process.viewport_args backend viewport
        @ keepawake_off @ f.daemon_flags;
      watch =
        Watch_hub.for_runs_dir ~daemon:f.daemon ~runs_dir:f.runs_dir f.watch;
    }
  in
  chain ~plan_dir setup ~first:true selected
