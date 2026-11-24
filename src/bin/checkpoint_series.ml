(* The selected checkpoints in order, each run until its policy decides
   (Story.Checkpoint_trials), stopping at the first that does not pass; the
   exit code. In verification mode a passing checkpoint's last passing end
   becomes the next checkpoint's start state, the one before kept beside it.
   StoryEngine::run_checkpoints() and verify_checkpoint() on the fork's
   frlg/lean; see Checkpoints_command. The chain's progress (Chain_progress)
   goes to the watch page from each run. A repeating checkpoint (mg-04b's grind
   round, Story.Plan.repeat) runs round by round instead, each round one run
   whatever the mode's policy. *)

open Story
module Run = Checkpoint_live_run

let ( let* ) = Result.bind
let load_plan = Plan_dir.load_plan

let next_plan ~plan_dir = function
  | None -> Ok None
  | Some n ->
      Result.map (fun (p : Plan.t) -> Some p.checkpoint) (load_plan ~plan_dir n)

(* On the Switch the console holds the start: the save the user loaded. *)
let start_state (setup : Run.setup) id =
  let path = Filename.concat setup.states (id ^ ".start.ss") in
  match setup.backend with
  | Daemon_process.Switch _ -> Ok "the console's last save"
  | Mgba _ when Sys.file_exists path -> Ok path
  | Mgba _ -> Error ("no start state " ^ path)

(* The whole checkpoint from its start state, or a partial run from its first
   event's kept state. *)
let start_and_partial (setup : Run.setup) id (plan : Plan.t) =
  match setup.from_event with
  | None -> Result.map (fun s -> (s, None)) (start_state setup id)
  | Some events ->
      Result.map
        (fun (state, partial) -> (state, Some partial))
        (Event_state_files.partial ~states:setup.states ~checkpoint:id
           plan.checkpoint events)

(* The checkpoint [id], its end declared by [next]'s plan. *)
let checkpoint ~plan_dir (setup : Run.setup) id ~next =
  let* plan = load_plan ~plan_dir id in
  let next_id = next in
  let* next = next_plan ~plan_dir next in
  let* start_state, partial = start_and_partial setup id plan in
  let* before = Plan_dir.promised_before ~plan_dir id in
  Ok
    {
      Run.id;
      plan;
      start_state;
      before;
      next_id;
      partial;
      end_at =
        (match plan.postconditions.position with
        | Some position -> Some position
        | None -> Checkpoint_end.declared ~next plan.checkpoint);
    }

let now_ms () = int_of_float (Unix.gettimeofday () *. 1000.)

let attempt_of : Run.outcome -> Checkpoint_trials.attempt = function
  | Passed _ -> Attempt_passed
  | Failed { at; reason; repeats } -> Attempt_failed { at; reason; repeats }

(* Run [n] of [cp]: attempts from its start until Checkpoint_trials.attempts
   decides; the last attempt's folder and the run's outcome, noted in that
   folder's summary.txt. *)
let rec attempts setup cp n ~progress tried =
  let attempt = List.length tried + 1 in
  let record, outcome = Run.run setup cp n ~attempt ~progress in
  let tried = tried @ [ attempt_of outcome ] in
  let decided why outcome =
    if cp.Run.plan.retries > 0 then (
      let line =
        Printf.sprintf "%s run %d: %s after %d of %d attempts" cp.id n why
          attempt (cp.plan.retries + 1)
      in
      print_endline ("[Checkpoints] " ^ line);
      Run_record.append record "summary.txt" (line ^ "\n"));
    (record, outcome)
  in
  match Checkpoint_trials.attempts ~retries:cp.plan.retries tried with
  | Attempt_again -> attempts setup cp n ~progress tried
  | Run_passed -> decided "passed" outcome
  | Run_failed _ when cp.plan.retries = 0 -> (record, outcome)
  | Run_failed { at; repeats; why } ->
      let reason = match outcome with Failed f -> f.reason | Passed _ -> "" in
      decided ("failed: " ^ why)
        (Run.Failed { at; reason = why ^ ": " ^ reason; repeats })

(* One run of [cp], [chain] updated around it. *)
let trial setup cp n chain =
  chain := Chain_progress.begin_trial !chain;
  let started = !chain in
  let progress = function
    | None -> Chain_progress.to_wire started ~now_ms:(now_ms ())
    | Some r ->
        let now_ms = now_ms () in
        Chain_progress.to_wire
          (Chain_progress.end_trial started r ~now_ms)
          ~now_ms
  in
  let ((_, outcome) as run) = attempts setup cp n ~progress [] in
  chain :=
    Chain_progress.end_trial started (Run.trial outcome) ~now_ms:(now_ms ());
  run

(* Runs [cp] until the policy decides; the verdict and the runs, oldest
   first. *)
let rec runs_of setup cp chain runs =
  match
    Checkpoint_trials.verdict setup.Run.policy
      (List.map (fun (_, o) -> Run.trial o) runs)
  with
  | Checkpoint_trials.Run_again ->
      let run = trial setup cp (List.length runs + 1) chain in
      runs_of setup cp chain (runs @ [ run ])
  | verdict -> (verdict, runs)

(* The last passing run's end.ss as [next]'s start (or [id].end.ss). *)
let keep_end (setup : Run.setup) id ~next runs =
  let target =
    match next with Some n -> n ^ ".start.ss" | None -> id ^ ".end.ss"
  in
  let dst = Filename.concat setup.states target in
  let passing =
    List.filter
      (fun (_, o) -> match o with Run.Passed _ -> true | Failed _ -> false)
      runs
  in
  match List.rev passing with
  | [] -> ()
  | (record, _) :: _ ->
      let src = Run_record.path record "end.ss" in
      if Sys.file_exists src then (
        if Sys.file_exists dst then
          Sys.rename dst (dst ^ ".replaced-" ^ Run_record.time ());
        Run_record.copy_file ~src ~dst;
        print_endline ("[Checkpoints] saved the end as " ^ dst))
      else print_endline ("[Checkpoints] no end.ss in " ^ record.dir)

(* A capped grind's end is not the next checkpoint's start: never saved. *)
let keep_uncapped_end (setup : Run.setup) id ~next runs =
  match setup.common.grind_cap with
  | Some cap ->
      Printf.printf
        "[Checkpoints] grind capped at %d: the end is not saved as the next \
         start state\n\
         %!"
        cap
  | None -> keep_end setup id ~next runs

(* Whether [cp] passed, after running it until its policy decided. *)
let decide (setup : Run.setup) (cp : Run.checkpoint) chain ~next =
  match runs_of setup cp chain [] with
  | Checkpoint_trials.Checkpoint_passed { passes; runs }, done_runs ->
      Printf.printf "[Checkpoints] %s: passed (%d of %d runs)%s\n%!" cp.id
        passes runs (Run.capped_note setup cp);
      if Event_range.keeps_end (Run.partial_range cp) setup.policy then
        keep_uncapped_end setup cp.id ~next done_runs;
      true
  | Checkpoint_trials.Stopped why, _ ->
      Printf.printf "[Checkpoints] %s: stopped: %s\n%!" cp.id why;
      false
  | Checkpoint_trials.Run_again, _ -> false

(* {1 A repeating checkpoint} Each round is one run (its attempts inside it),
   saved like any checkpoint's pass: on the Switch in the game
   (--save-after-pass), on mGBA as the run's end.ss, the next round's start.
   The rounds go on until the goal, read after each passing round, holds
   (Story.Round_trials). *)

let round_of : Run.outcome -> Round_trials.round = function
  | Passed { goal } -> Round_passed { goal_met = goal = Some true }
  | Failed { at; reason; _ } -> Round_failed (at ^ ": " ^ reason)

(* The round after a passing one starts from its end: on mGBA its end.ss. *)
let after_round (setup : Run.setup) (cp : Run.checkpoint) (record, outcome) =
  match (setup.backend, outcome) with
  | Daemon_process.Mgba _, Run.Passed _ ->
      { cp with start_state = Run_record.path record "end.ss" }
  | _ -> cp

let rounds_ended (setup : Run.setup) (cp : Run.checkpoint) chain ~next runs
    decision =
  let passed =
    match decision with
    | Round_trials.Goal_met _ | Capped _ -> true
    | Next_round _ | Stopped _ -> false
  in
  Printf.printf "[Checkpoints] %s: %s: %s%s\n%!" cp.id
    (if passed then "passed" else "stopped")
    (Round_trials.decision_to_string decision)
    (Run.capped_note setup cp);
  chain := Chain_progress.end_rounds !chain ~passed ~now_ms:(now_ms ());
  if passed && setup.policy.keeps_end then
    keep_uncapped_end setup cp.id ~next runs;
  passed

let rec rounds (setup : Run.setup) cp chain ~next ~max_rounds runs =
  let capped = setup.common.grind_cap <> None in
  match
    Round_trials.decide ~max_rounds ~capped
      (List.map (fun (_, o) -> round_of o) runs)
  with
  | Next_round n ->
      Printf.printf "[Checkpoints] %s round %d of at most %d\n%!" cp.Run.id n
        max_rounds;
      let run = trial setup cp n chain in
      rounds setup (after_round setup cp run) chain ~next ~max_rounds
        (runs @ [ run ])
  | decision -> rounds_ended setup cp chain ~next runs decision

let repeat (setup : Run.setup) (cp : Run.checkpoint) chain ~next
    (r : Plan.repeat) =
  let max_rounds = Option.value setup.max_rounds ~default:r.max_rounds in
  chain := Chain_progress.begin_rounds !chain ~max_rounds;
  rounds setup cp chain ~next ~max_rounds []

let one ~plan_dir setup id chain ~next =
  chain := Chain_progress.begin_checkpoint !chain id ~now_ms:(now_ms ());
  match checkpoint ~plan_dir setup id ~next with
  | Ok ({ plan = { repeat = Some r; _ }; _ } as cp) ->
      repeat setup cp chain ~next r
  | Ok cp -> decide setup cp chain ~next
  | Error e ->
      print_endline ("[Checkpoints] " ^ id ^ ": " ^ e);
      chain := Chain_progress.fail_checkpoint !chain ~now_ms:(now_ms ());
      false

let rec chain_from ~plan_dir setup ids chain ~after =
  match ids with
  | [] -> 0
  | id :: rest ->
      let next = match rest with n :: _ -> Some n | [] -> after in
      if one ~plan_dir setup id chain ~next then
        chain_from ~plan_dir setup rest chain ~after
      else 1

let run ~plan_dir (setup : Run.setup) ids ~after =
  let chain =
    ref
      (Chain_progress.create ~mode:setup.mode ~policy:setup.policy
         ~started_ms:(now_ms ()) ids)
  in
  chain_from ~plan_dir setup ids chain ~after
