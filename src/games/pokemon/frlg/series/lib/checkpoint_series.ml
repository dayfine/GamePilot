(* The selected checkpoints in order, each run until its policy decides
   (Engine_run.Checkpoint_trials), stopping at the first that does not pass; the
   exit code. In verification mode a passing checkpoint's last passing end
   becomes the next checkpoint's start state, the one before kept beside it.
   StoryEngine::run_checkpoints() and verify_checkpoint() on the fork's
   frlg/lean; see Run_command. The chain's progress (Chain_progress)
   goes to the watch page from each run. A repeating checkpoint (05-grind-mr-mime's grind
   round, Pokemon_engine.Plan.repeat) runs round by round instead, each round one run
   whatever the mode's policy. *)

open Engine_run
open Engine_series
open Pokemon_engine
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
  let apply =
    Option.map
      (Frlg_checkpoints.Plan_file.apply_postcondition_options
         setup.program_options)
  in
  let plan = { plan with postconditions = apply plan.postconditions } in
  let next_id = next in
  let* next = next_plan ~plan_dir next in
  let* start_state, partial = start_and_partial setup id plan in
  let* before = Plan_dir.promised_before ~plan_dir id in
  let before = apply before in
  Ok
    {
      Run.id;
      plan;
      start_state;
      before;
      next_id;
      partial;
      end_at =
        (match Option.bind plan.postconditions (fun p -> p.position) with
        | Some position -> Some position
        | None -> Checkpoint_end.declared ~next plan.checkpoint);
    }

let now_ms = Run_record.now_ms

let attempt_of : Run.outcome -> Checkpoint_trials.attempt = function
  | Passed _ -> Attempt_passed
  | Failed { at; reason; repeats } -> Attempt_failed { at; reason; repeats }

let record_retry_decision cp n ~attempt record why =
  if cp.Run.plan.retries > 0 then (
    let line =
      Printf.sprintf "%s run %d: %s after %d of %d attempts" cp.id n why attempt
        (cp.plan.retries + 1)
    in
    print_endline ("[Checkpoints] " ^ line);
    Run_record.append record "summary.txt" (line ^ "\n"))

let finish_attempts cp n (attempt, (record, outcome), verdict) =
  match verdict with
  | Checkpoint_trials.Run_passed ->
      record_retry_decision cp n ~attempt record "passed";
      (record, outcome)
  | Run_failed _ when cp.Run.plan.retries = 0 -> (record, outcome)
  | Run_failed { at; repeats; why } ->
      let reason =
        match outcome with Run.Failed f -> f.reason | Passed _ -> ""
      in
      record_retry_decision cp n ~attempt record ("failed: " ^ why);
      (record, Run.Failed { at; reason = why ^ ": " ^ reason; repeats })
  | Attempt_again -> (record, outcome)

(* Run [n] of [cp]: attempts from its start until Checkpoint_trials.attempts
   decides; the last attempt's folder and the run's outcome, noted in that
   folder's summary.txt. [Error] when an attempt's folder could not be made. *)
let attempts setup cp n ~trial_ctx ~progress =
  let rec go tried =
    let attempt = List.length tried + 1 in
    let already_at_start =
      Series_chain.trial_already_at_start trial_ctx ~attempt
    in
    let* res = Run.run setup cp n ~attempt ~already_at_start ~progress in
    let tried = tried @ [ attempt_of (snd res) ] in
    match Checkpoint_trials.attempts ~retries:cp.Run.plan.retries tried with
    | Attempt_again -> go tried
    | (Run_passed | Run_failed _) as verdict ->
        Ok (finish_attempts cp n (attempt, res, verdict))
  in
  go []

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
        "[Checkpoints] grind capped at %d: end not saved as next start state\n\
         %!"
        cap
  | None -> keep_end setup id ~next runs

let record_species cp_id species =
  match Dex_targets.record_caught species with
  | Ok () ->
      Printf.printf "[Checkpoints] %s: recorded %s in local dex progress\n%!"
        cp_id species
  | Error e ->
      Printf.printf "[Checkpoints] %s: dex progress not saved: %s\n%!" cp_id e

let record_dex_progress (setup : Run.setup) (cp : Run.checkpoint) =
  match
    ( Run_options.find setup.program_options "target",
      Dex_targets.plan_species cp.plan )
  with
  | Some _, Some species -> record_species cp.id species
  | _ -> ()

let on_pass (setup : Run.setup) (cp : Run.checkpoint) ~next runs =
  record_dex_progress setup cp;
  if Event_range.keeps_end (Run.partial_range cp) setup.policy then
    keep_uncapped_end setup cp.id ~next runs

(* {1 A repeating checkpoint} Each round is one run (its attempts inside it),
   saved like any checkpoint's pass: on the Switch in the game
   (--save-after-pass), on mGBA as the run's end.ss, the next round's start.
   The rounds go on until the goal, read after each passing round, holds
   (Engine_series.Round_trials). *)

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

let repeat ~chain ~run_trial (setup : Run.setup) (cp : Run.checkpoint)
    ~from_pass ~next (r : Plan.repeat) =
  let max_rounds = Option.value setup.max_rounds ~default:r.max_rounds in
  let capped = setup.common.grind_cap <> None in
  chain := Chain_progress.begin_rounds !chain ~max_rounds;
  let rec go cp ~from_pass runs =
    match
      Round_trials.decide ~max_rounds ~capped
        (List.map (fun (_, o) -> round_of o) runs)
    with
    | Next_round number -> step cp ~from_pass runs ~number
    | decision -> (decision, runs)
  and step (cp : Run.checkpoint) ~from_pass runs ~number =
    Printf.printf "[Checkpoints] %s round %d of at most %d\n%!" cp.id number
      max_rounds;
    let trial_ctx =
      { Series_chain.number = 1; continuing_from_pass = from_pass }
    in
    match run_trial (cp, Some number) trial_ctx with
    | Ok ((_, outcome) as res) ->
        let from_pass =
          match outcome with Run.Passed _ -> true | _ -> false
        in
        go (after_round setup cp res) ~from_pass (runs @ [ res ])
    | Error e -> (Round_trials.Stopped e, runs)
  in
  let decision, runs = go cp ~from_pass [] in
  rounds_ended setup cp chain ~next runs decision

let repeat_if_needed setup ~chain ~run_trial ((cp : Run.checkpoint), _)
    ~continuing_from_pass ~next =
  Option.map
    (repeat ~chain ~run_trial setup cp ~from_pass:continuing_from_pass ~next)
    cp.plan.repeat

let run_trial_of setup (cp, round) (trial_ctx : Series_chain.trial) ~progress =
  let n = Option.value round ~default:trial_ctx.number in
  attempts setup cp n ~trial_ctx ~progress

let hooks_of ~plan_dir (setup : Run.setup) :
    ( string,
      Run.checkpoint * int option,
      Run_record.t * Run.outcome )
    Series_runner.hooks =
  {
    entry_id = Fun.id;
    prepare =
      (fun id ~next ->
        Result.map (fun cp -> (cp, None)) (checkpoint ~plan_dir setup id ~next));
    run_trial = run_trial_of setup;
    trial_of = (fun (_, o) -> Run.trial o);
    verdict_note = (fun (cp, _) -> Run.capped_note setup cp);
    on_pass = (fun (cp, _) ~next runs -> on_pass setup cp ~next runs);
  }

let run ~plan_dir (setup : Run.setup) ids ~after =
  let hooks = hooks_of ~plan_dir setup in
  let passed =
    Series_runner.run ~mode:setup.mode ~policy:setup.policy ~now_ms
      ~log:print_endline ?after ~override:(repeat_if_needed setup) hooks ids
  in
  Series_daemons.finish_series setup.daemons ~close_game:setup.close_game
    ?tile:setup.home_tile ~passed ()
