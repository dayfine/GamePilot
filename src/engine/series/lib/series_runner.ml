open Engine_run

type progress = Checkpoint_trials.run option -> Wire.Watch_run.t

type ('entry, 'plan, 'run) hooks = {
  entry_id : 'entry -> string;
  prepare : 'entry -> next:'entry option -> ('plan, string) result;
  run_trial :
    'plan -> Series_chain.trial -> progress:progress -> ('run, string) result;
  trial_of : 'run -> Checkpoint_trials.run;
  verdict_note : 'plan -> string;
  on_pass : 'plan -> next:'entry option -> 'run list -> unit;
}

let wire_progress ~now_ms started = function
  | None -> Chain_progress.to_wire started ~now_ms:(now_ms ())
  | Some r ->
      let t = now_ms () in
      Chain_progress.to_wire
        (Chain_progress.end_trial started r ~now_ms:t)
        ~now_ms:t

let run_tracked_trial ~now_ms hooks chain plan trial =
  chain := Chain_progress.begin_trial !chain;
  let started = !chain in
  let progress = wire_progress ~now_ms started in
  match hooks.run_trial plan trial ~progress with
  | Ok run as res ->
      chain :=
        Chain_progress.end_trial started (hooks.trial_of run)
          ~now_ms:(now_ms ());
      res
  | Error _ as err ->
      chain := Chain_progress.fail_checkpoint !chain ~now_ms:(now_ms ());
      err

let decide ~policy ~now_ms ~log hooks chain ~id ~continuing_from_pass ~next plan
    =
  let verdict, runs =
    Series_chain.run_trials policy ~continuing_from_pass ~trial:hooks.trial_of
      (run_tracked_trial ~now_ms hooks chain plan)
  in
  let passed, line =
    Series_chain.verdict_outcome ~note:(hooks.verdict_note plan) ~id verdict
  in
  Option.iter log line;
  if passed then hooks.on_pass plan ~next runs;
  passed

let run_prepared ~policy ~now_ms ~log ?override hooks chain ~id
    ~continuing_from_pass ~next plan =
  let run_trial = run_tracked_trial ~now_ms hooks chain in
  let overridden =
    Option.bind override (fun f ->
        f ~chain ~run_trial plan ~continuing_from_pass ~next)
  in
  match overridden with
  | Some passed -> passed
  | None ->
      decide ~policy ~now_ms ~log hooks chain ~id ~continuing_from_pass ~next
        plan

let run_one ~policy ~now_ms ~log ?override hooks chain
    (item : 'entry Series_chain.item) =
  let id = hooks.entry_id item.value in
  chain := Chain_progress.begin_checkpoint !chain id ~now_ms:(now_ms ());
  match hooks.prepare item.value ~next:item.next with
  | Error e ->
      log ("[Checkpoints] " ^ id ^ ": " ^ e);
      chain := Chain_progress.fail_checkpoint !chain ~now_ms:(now_ms ());
      false
  | Ok plan ->
      run_prepared ~policy ~now_ms ~log ?override hooks chain ~id
        ~continuing_from_pass:item.continuing_from_pass ~next:item.next plan

let run ~mode ~policy ~now_ms ~log ?after ?override hooks entries =
  let ids = List.map hooks.entry_id entries in
  let chain =
    ref (Chain_progress.create ~mode ~policy ~started_ms:(now_ms ()) ids)
  in
  Series_chain.run_chain ?after entries
    (run_one ~policy ~now_ms ~log ?override hooks chain)
