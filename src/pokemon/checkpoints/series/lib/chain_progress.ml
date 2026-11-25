open Checkpoints_run
module W = Wire.Watch_run
module Trials = Checkpoint_trials

type entry = {
  id : string;
  state : W.state;
  spent_ms : int;  (** Before [since_ms], or in all for a finished one. *)
  since_ms : int option;  (** When it became current, while it is. *)
}

type t = {
  mode : Trials.mode;
  policy : Trials.policy;
  started_ms : int;
  entries : entry list;
  runs : Trials.run list;  (** The current checkpoint's, oldest first. *)
  running : bool;
  max_rounds : int option;  (** The current checkpoint's, when it repeats. *)
}

let create ~mode ~policy ~started_ms ids =
  let pending id = { id; state = W.Pending; spent_ms = 0; since_ms = None } in
  {
    mode;
    policy;
    started_ms;
    entries = List.map pending ids;
    runs = [];
    running = false;
    max_rounds = None;
  }

let update_current t f =
  {
    t with
    entries =
      List.map (fun e -> if e.state = W.Current then f e else e) t.entries;
  }

let begin_checkpoint t id ~now_ms =
  let start e =
    if e.id = id then { e with state = W.Current; since_ms = Some now_ms }
    else e
  in
  {
    t with
    entries = List.map start t.entries;
    runs = [];
    running = false;
    max_rounds = None;
  }

let begin_trial t = { t with running = true }

let elapsed e ~now_ms =
  match e.since_ms with
  | Some since -> e.spent_ms + now_ms - since
  | None -> e.spent_ms

let finish t state ~now_ms =
  let t =
    update_current t (fun e ->
        { state; spent_ms = elapsed e ~now_ms; since_ms = None; id = e.id })
  in
  if state = W.Failed then
    let skip e =
      if e.state = W.Pending then { e with state = W.Skipped } else e
    in
    { t with entries = List.map skip t.entries }
  else t

let end_trial t run ~now_ms =
  let t = { t with runs = t.runs @ [ run ]; running = false } in
  match Trials.verdict t.policy t.runs with
  | _ when t.max_rounds <> None -> t
  | Trials.Run_again -> t
  | Trials.Checkpoint_passed _ -> finish t W.Passed ~now_ms
  | Trials.Stopped _ -> finish t W.Failed ~now_ms

let begin_rounds t ~max_rounds = { t with max_rounds = Some max_rounds }

let end_rounds t ~passed ~now_ms =
  finish { t with running = false }
    (if passed then W.Passed else W.Failed)
    ~now_ms

let fail_checkpoint t ~now_ms =
  finish { t with running = false } W.Failed ~now_ms

let count p runs = List.length (List.filter p runs)

let to_wire t ~now_ms =
  let checkpoint e =
    { W.id = e.id; state = e.state; elapsed_ms = elapsed e ~now_ms }
  in
  {
    W.mode = Trials.mode_to_string t.mode;
    trial = (List.length t.runs + if t.running then 1 else 0);
    trials = Option.value t.max_rounds ~default:t.policy.runs;
    passes = count (fun r -> r = Trials.Passed) t.runs;
    fails = count (fun r -> r <> Trials.Passed) t.runs;
    started_ms = t.started_ms;
    checkpoints = List.map checkpoint t.entries;
  }
