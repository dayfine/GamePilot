(* One run of one checkpoint on the live emulator: a run folder, a daemon
   logging to it, the checkpoint from its start state through
   Frlg_story.Checkpoint_run with its declared end, then the saves the outcome
   asks for (the failure frame and state, or a passing end) while the session
   is still open, and the run's summary, KEEP and RESULTS.tsv row. *)

open Story

type setup = {
  states : string;
  runs_dir : string;
  daemon : string;
  mgba_port : int;
  common : Checkpoint_command.flags;
  mode : Checkpoint_trials.mode;
  policy : Checkpoint_trials.policy;
  world : Frlg_overworld.Frlg_steps.world;
}

type checkpoint = {
  id : string;  (** The plan file's name, e.g. ["mg-04"]. *)
  plan : Plan.t;
  end_at : Pose.grid option;
  start_state : string;
}

type outcome =
  | Passed
  | Failed of { at : string; reason : string; repeats : bool }

let trial = function
  | Passed -> Checkpoint_trials.Passed
  | Failed { at; repeats; _ } -> Checkpoint_trials.Failed { at; repeats }

let of_failure (f : Failure.t) =
  Failed
    {
      at = Printf.sprintf "#%d %s" (f.event_index + 1) f.event_id;
      reason = Failure.reason_to_string f.reason;
      repeats = Failure.repeats f;
    }

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
    state = Some cp.start_state;
    log;
  }

(* In the session: the checkpoint, then the outcome's saves. *)
let in_session setup cp record log () =
  let outcome =
    match
      Frlg_story.Checkpoint_run.run ?end_at:cp.end_at (options setup cp log)
        setup.world cp.plan
    with
    | Ok () -> Passed
    | Error failure -> of_failure failure
    | exception (Effects.Disconnected _ as e) -> raise e
    | exception e ->
        Failed { at = "raised"; reason = Printexc.to_string e; repeats = false }
  in
  let path = Run_record.path record in
  (match outcome with
  | Failed _ ->
      save log "failure.png" (fun () -> Effects.save_frame (path "failure.png"));
      save log "failure.ss" (fun () -> Effects.save_state (path "failure.ss"))
  | Passed when setup.policy.keeps_end ->
      save log "end.ss" (fun () -> Effects.save_state (path "end.ss"))
  | Passed -> ());
  outcome

let live setup cp record log =
  match Live.run ~port:setup.common.port (in_session setup cp record log) with
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

let with_daemon setup record body =
  match
    Daemon_process.start ~daemon:setup.daemon ~mgba_port:setup.mgba_port
      ~port:setup.common.port
      ~wire_log:(Run_record.path record "wire.jsonl")
      ~out_file:(Run_record.path record "daemon.out")
  with
  | Error reason -> Failed { at = "daemon"; reason; repeats = true }
  | Ok daemon ->
      Fun.protect
        ~finally:(fun () -> Daemon_process.stop daemon)
        (fun () -> body daemon)

let summary cp n = function
  | Passed -> Printf.sprintf "PASS %s run %d" cp.id n
  | Failed { at; reason; _ } ->
      Printf.sprintf "FAIL %s run %d at %s: %s" cp.id n at reason

let record_outcome setup cp record n outcome =
  let line = summary cp n outcome in
  print_endline ("[Run] " ^ record.Run_record.dir ^ ": " ^ line);
  Run_record.write record "summary.txt" (line ^ "\n");
  let result, at, reason =
    match outcome with
    | Passed -> ("pass", "", "")
    | Failed { at; reason; _ } ->
        Run_record.write record "KEEP" "a failing run\n";
        ("fail", at, reason)
  in
  Run_record.append_result ~runs_dir:setup.runs_dir record ~checkpoint:cp.id
    ~mode:(Checkpoint_trials.mode_to_string setup.mode)
    ~result ~at ~reason

(* Run [n] of [cp]: its folder and how it ended. *)
let run setup cp n =
  let record =
    Run_record.create ~runs_dir:setup.runs_dir ~checkpoint:cp.id
      ~mode:(Checkpoint_trials.mode_to_string setup.mode)
  in
  let log, close = Run_record.story_log record in
  log (Printf.sprintf "[Run] %s run %d from %s" cp.id n cp.start_state);
  let outcome =
    with_daemon setup record (fun _daemon -> live setup cp record log)
  in
  close ();
  record_outcome setup cp record n outcome;
  (record, outcome)
