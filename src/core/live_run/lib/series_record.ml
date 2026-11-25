(* What the watch page shows of a checkpoint series as one run: each
   checkpoint's state, runs and times, the run going now, and the series' end
   (docs/design/Watch-Page.md, One page per series). Pure. *)

type state = Pending | Current | Passed | Failed | Skipped

type run = {
  name : string;
  n : int;
  attempt : int;
  started_ms : int;
  ended : (int * Run_record.ending) option;
}

type checkpoint = {
  cp : string;
  state : state;
  cp_started_ms : int option;
  cp_ended_ms : int option;
  runs : run list;
}

type t = {
  id : string;
  pid : int;
  info : Run_record.info;
  mode : string;
  started_ms : int;
  ended_ms : int option;
  result : string;
  going : string option;
  checkpoints : checkpoint list;
}

let pending cp =
  { cp; state = Pending; cp_started_ms = None; cp_ended_ms = None; runs = [] }

let create ~id ~pid info ~mode ~started_ms ids =
  {
    id;
    pid;
    info;
    mode;
    started_ms;
    ended_ms = None;
    result = "running";
    going = None;
    checkpoints = List.map pending ids;
  }

let id t = t.id

(* [cp] after the current checkpoint, else before the first to come. *)
let insert cp checkpoints =
  let current = List.exists (fun c -> c.state = Current) checkpoints in
  let rec go = function
    | [] -> [ pending cp ]
    | c :: rest when current && c.state = Current -> c :: pending cp :: rest
    | c :: rest when (not current) && c.state = Pending ->
        pending cp :: c :: rest
    | c :: rest -> c :: go rest
  in
  go checkpoints

let listed t cp =
  if List.exists (fun c -> c.cp = cp) t.checkpoints then t.checkpoints
  else insert cp t.checkpoints

(* When a checkpoint's last run ended, else [default]. *)
let last_end c ~default =
  match List.rev c.runs with
  | { ended = Some (ms, _); _ } :: _ -> ms
  | _ -> default

let begin_run t (r : Run_record.run) ~n =
  let run =
    {
      name = r.record.name;
      n;
      attempt = Option.fold ~none:1 ~some:fst r.attempt;
      started_ms = r.started_ms;
      ended = None;
    }
  in
  let update c =
    if c.cp = r.checkpoint then
      {
        c with
        state = Current;
        cp_started_ms =
          Some (Option.value c.cp_started_ms ~default:r.started_ms);
        runs = c.runs @ [ run ];
      }
    else if c.state = Current then
      {
        c with
        state = Passed;
        cp_ended_ms = Some (last_end c ~default:r.started_ms);
      }
    else c
  in
  {
    t with
    going = Some run.name;
    checkpoints = List.map update (listed t r.checkpoint);
  }

let end_run t (r : Run_record.run) ending ~now_ms =
  let name = r.record.name in
  let close run =
    if run.name = name then { run with ended = Some (now_ms, ending) } else run
  in
  {
    t with
    going = (if t.going = Some name then None else t.going);
    checkpoints =
      List.map (fun c -> { c with runs = List.map close c.runs }) t.checkpoints;
  }

let finish t ~passed ~now_ms =
  let update c =
    match c.state with
    | Current ->
        {
          c with
          state = (if passed then Passed else Failed);
          cp_ended_ms = Some now_ms;
        }
    | Pending when not passed -> { c with state = Skipped }
    | Pending | Passed | Failed | Skipped -> c
  in
  {
    t with
    ended_ms = Some now_ms;
    result = (if passed then "pass" else "fail");
    going = None;
    checkpoints = List.map update t.checkpoints;
  }

let state_name = function
  | Pending -> "pending"
  | Current -> "current"
  | Passed -> "passed"
  | Failed -> "failed"
  | Skipped -> "skipped"

let int_field name = function Some v -> [ (name, `Int v) ] | None -> []

let run_json run =
  let ended =
    match run.ended with
    | None -> [ ("result", `String "running") ]
    | Some (ms, (e : Run_record.ending)) ->
        [
          ("ended_ms", `Int ms);
          ("result", `String e.result);
          ("at", `String e.at);
          ("reason", `String e.reason);
        ]
  in
  `Assoc
    ([
       ("run", `String run.name);
       ("n", `Int run.n);
       ("attempt", `Int run.attempt);
       ("started_ms", `Int run.started_ms);
     ]
    @ ended)

let checkpoint_json c =
  `Assoc
    ([ ("id", `String c.cp); ("state", `String (state_name c.state)) ]
    @ int_field "started_ms" c.cp_started_ms
    @ int_field "ended_ms" c.cp_ended_ms
    @ [ ("runs", `List (List.map run_json c.runs)) ])

let to_json t =
  `Assoc
    ([ ("series", `String t.id); ("pid", `Int t.pid) ]
    @ List.map (fun (k, v) -> (k, `String v)) t.info.program
    @ [
        ("from", `String t.info.from_id);
        ("to", `String t.info.to_id);
        ("mode", `String t.mode);
        ("backend", `String t.info.backend);
        ("started_ms", `Int t.started_ms);
      ]
    @ int_field "ended_ms" t.ended_ms
    @ [ ("result", `String t.result) ]
    @ Option.fold ~none:[] ~some:(fun r -> [ ("run", `String r) ]) t.going
    @ [ ("checkpoints", `List (List.map checkpoint_json t.checkpoints)) ])
