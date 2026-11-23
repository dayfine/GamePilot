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
