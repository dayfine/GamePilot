type mode = Testing | Verification

let mode_of_string = function
  | "testing" -> Some Testing
  | "verification" -> Some Verification
  | _ -> None

let mode_to_string = function
  | Testing -> "testing"
  | Verification -> "verification"

type policy = { runs : int; passes_needed : int; keeps_end : bool }

(* VerifyModePolicy{runs = 3, passes_needed = 2}. *)
let verification_runs = 3
let verification_passes = 2
let testing = { runs = 1; passes_needed = 1; keeps_end = false }

let verification =
  {
    runs = verification_runs;
    passes_needed = verification_passes;
    keeps_end = true;
  }

let mode_policy ?runs mode =
  let p = match mode with Testing -> testing | Verification -> verification in
  { p with runs = Option.value runs ~default:p.runs }

let policy ?runs mode =
  let p = mode_policy ?runs mode in
  if p.runs >= 1 && p.runs >= p.passes_needed then Ok p
  else
    Error
      (Printf.sprintf "%s needs %d passes, so at least %d runs"
         (mode_to_string mode) p.passes_needed (max 1 p.passes_needed))

type run = Passed | Failed of { at : string; repeats : bool }

type verdict =
  | Run_again
  | Checkpoint_passed of { passes : int; runs : int }
  | Stopped of string

let passes runs = List.length (List.filter (( = ) Passed) runs)

let early_stop = function
  | Failed { at; _ } :: Failed { at = before; _ } :: _ when at = before ->
      Some ("hard stop: failed twice in a row at " ^ at)
  | Failed { at; repeats = true } :: _ -> Some ("the failure repeats: " ^ at)
  | _ -> None

let verdict policy runs =
  match early_stop (List.rev runs) with
  | Some why -> Stopped why
  | None when List.length runs < policy.runs -> Run_again
  | None when passes runs >= policy.passes_needed ->
      Checkpoint_passed { passes = passes runs; runs = List.length runs }
  | None ->
      Stopped
        (Printf.sprintf "%d of %d runs passed, %d needed" (passes runs)
           (List.length runs) policy.passes_needed)

type attempt = Attempt_passed | Attempt_failed of failure
and failure = { at : string; reason : string; repeats : bool }

type attempt_verdict =
  | Attempt_again
  | Run_passed
  | Run_failed of { at : string; repeats : bool; why : string }

let same_failure a b = a.at = b.at && a.reason = b.reason

let all_failed_alike = function
  | Attempt_failed first :: rest ->
      List.for_all
        (function
          | Attempt_failed f -> same_failure f first | Attempt_passed -> false)
        rest
  | _ -> false

let out_of_attempts attempts (last : failure) =
  let n = List.length attempts in
  let alike = n > 1 && all_failed_alike attempts in
  let why =
    if alike then
      Printf.sprintf "failed the same way on all %d attempts: %s" n last.reason
    else Printf.sprintf "failed on all %d attempts" n
  in
  Run_failed { at = last.at; repeats = alike || last.repeats; why }

let attempts ~retries attempts =
  match List.rev attempts with
  | [] -> Attempt_again
  | Attempt_passed :: _ -> Run_passed
  | Attempt_failed f :: _ when f.repeats ->
      Run_failed { at = f.at; repeats = true; why = "the failure repeats" }
  | Attempt_failed _ :: _ when List.length attempts <= retries -> Attempt_again
  | Attempt_failed f :: _ -> out_of_attempts attempts f

let until_decided policy ~trial run =
  let rec go runs =
    match verdict policy (List.map trial runs) with
    | Run_again -> (
        match run (List.length runs + 1) with
        | Ok r -> go (runs @ [ r ])
        | Error why -> (Stopped why, runs))
    | decided -> (decided, runs)
  in
  go []
