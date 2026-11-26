(* Run_attempts over scripted attempts: which attempts reload first, and how
   the run ends; one fact per check. *)

module A = Plza_autostory.Run_attempts

let off_start =
  A.Failed
    {
      at = "start";
      reason = "chain_off_start: the run is not at 03.07's start";
      repeats = true;
      off_start = true;
    }

(* A failure a reload may fix: it does not repeat. *)
let missed =
  A.Failed
    {
      at = "#1 to_the_center";
      reason = "walk_no_end: no A prompt after the legs";
      repeats = false;
      off_start = false;
    }

let stuck =
  A.Failed
    {
      at = "#1 to_the_center";
      reason = "walk_stick: no stick";
      repeats = true;
      off_start = false;
    }

type ran = { reloads : bool list; log : string list; ended : A.outcome }

(* The attempts [script] gives in turn (then passes): whether each began with
   a reload, the log, and the run's end. *)
let attempts ?(has_start = true) ?(retries = 0) ?(reload_first = false) script =
  let left = ref script in
  let reloads = ref [] in
  let log = ref [] in
  let attempt ~attempt:_ ~reload =
    reloads := reload :: !reloads;
    match !left with
    | o :: rest ->
        left := rest;
        o
    | [] -> A.Passed
  in
  let ended =
    A.run ~has_start ~retries ~reload_first
      ~log:(fun l -> log := l :: !log)
      attempt
  in
  { reloads = List.rev !reloads; log = List.rev !log; ended }

let reloads ran =
  String.concat ", "
    (List.map (fun r -> if r then "reload" else "as is") ran.reloads)

let ended ran =
  match ran.ended with
  | A.Passed -> "passed"
  | A.Failed f -> "failed at " ^ f.at

let reason ran = match ran.ended with A.Passed -> "" | A.Failed f -> f.reason

let repeats ran =
  match ran.ended with
  | A.Passed -> "passed"
  | A.Failed f -> string_of_bool f.repeats

let logged ran part =
  string_of_bool
    (List.exists (fun l -> Strings.Contains.substring l part) ran.log)

let case name check expectation : Table_test.case =
  { name; input = (fun () -> check ()); expectation }

let off_once () = attempts [ off_start ]
let off_twice () = attempts [ off_start; off_start ]
let missed_retried () = attempts ~retries:2 [ missed ]
let missed_thrice () = attempts ~retries:2 [ missed; missed; missed ]

let cases =
  [
    case "off its start: the second attempt reloads"
      (fun () -> reloads (off_once ()))
      "as is, reload";
    case "off its start once: then it passes"
      (fun () -> ended (off_once ()))
      "passed";
    case "off its start: the log says why it reloads"
      (fun () -> logged (off_once ()) "off its start (chain_off_start")
      "true";
    case "off its start after the reload: fails at start"
      (fun () -> ended (off_twice ()))
      "failed at start";
    case "off its start after the reload: a failure that repeats"
      (fun () -> repeats (off_twice ()))
      "true";
    case "off its start after the reload: the reason says so"
      (fun () ->
        string_of_bool
          (String.starts_with ~prefix:"off its start after a reload"
             (reason (off_twice ()))))
      "true";
    case "a run that began with a reload: no second reload"
      (fun () -> reloads (attempts ~reload_first:true [ off_start ]))
      "reload";
    case "no start to go back to (01.01): no reload"
      (fun () -> reloads (attempts ~has_start:false [ off_start ]))
      "as is";
    case "no start to go back to: fails at start"
      (fun () -> ended (attempts ~has_start:false [ off_start ]))
      "failed at start";
    case "a failure, no retries: no second attempt"
      (fun () -> reloads (attempts [ missed ]))
      "as is";
    case "a failure, no retries: fails at its event"
      (fun () -> ended (attempts [ missed ]))
      "failed at #1 to_the_center";
    case "a failure, no retries: it does not repeat"
      (fun () -> repeats (attempts [ missed ]))
      "false";
    case "a failure once, retries 2: the retry reloads"
      (fun () -> reloads (missed_retried ()))
      "as is, reload";
    case "a failure once, retries 2: then it passes"
      (fun () -> ended (missed_retried ()))
      "passed";
    case "a failure once, retries 2: the log says it tries again"
      (fun () -> logged (missed_retried ()) "a reload may fix: trying again")
      "true";
    case "a failure three times, retries 2: three attempts"
      (fun () -> reloads (missed_thrice ()))
      "as is, reload, reload";
    case "a failure three times, retries 2: fails, as a failure that repeats"
      (fun () -> repeats (missed_thrice ()))
      "true";
    case "a failure three times, retries 2: the reason counts the attempts"
      (fun () ->
        string_of_bool
          (Strings.Contains.substring
             (reason (missed_thrice ()))
             "on all 3 attempts"))
      "true";
    case "off its start, then two failures, retries 2: the reload is no retry"
      (fun () -> reloads (attempts ~retries:2 [ off_start; missed; missed ]))
      "as is, reload, reload, reload";
    case "a failure that repeats, retries 2: no second attempt"
      (fun () -> reloads (attempts ~retries:2 [ stuck ]))
      "as is";
    case "retries with no start to go back to: no reload"
      (fun () -> reloads (attempts ~has_start:false ~retries:2 [ missed ]))
      "as is";
    case "the start check's chain_off_start is off its start"
      (fun () ->
        string_of_bool
          (A.off_start
             (Engine_run.Failure.cause ~repeats:true "chain_off_start" "")))
      "true";
    case "a walk's failure is not off its start"
      (fun () ->
        string_of_bool (A.off_start (Engine_run.Failure.cause "walk_no_end" "")))
      "false";
  ]

let () = Table_test.run "plza run attempts" cases
