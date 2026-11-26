module Trials = Engine_run.Checkpoint_trials

type failure = {
  at : string;
  reason : string;
  repeats : bool;
  off_start : bool;
}

type outcome = Passed | Failed of failure

let off_start_codes = [ "chain_off_start"; "rocks_not_left" ]
let off_start (c : Engine_run.Failure.cause) = List.mem c.code off_start_codes

let of_cause ~at (c : Engine_run.Failure.cause) =
  Failed
    {
      at;
      reason = Engine_run.Failure.cause_to_string c;
      repeats = c.repeats;
      off_start = off_start c;
    }

let of_failure (f : Plza_engine.Failure.t) =
  Failed
    {
      at = Printf.sprintf "#%d %s" (f.event_index + 1) f.event_id;
      reason = Plza_engine.Failure.reason_to_string f.reason;
      repeats = Plza_engine.Failure.repeats f;
      off_start = (match f.reason with Handler c -> off_start c | _ -> false);
    }

let trial = function
  | Passed -> Trials.Passed
  | Failed { at; repeats; _ } -> Trials.Failed { at; repeats }

(* What the engine's retry rule sees of an attempt. *)
let attempt_of = function
  | Passed -> Trials.Attempt_passed
  | Failed { at; reason; repeats; _ } ->
      Trials.Attempt_failed { at; reason; repeats }

type next = Again of string | Ended of outcome

let reload_why (f : failure) =
  Printf.sprintf
    "off its start (%s): back to the latest autosave, and its start checked \
     again"
    f.reason

(* Off its start, on an attempt that did not begin with a reload. *)
let reload_off_start ~has_start ~reloaded = function
  | Failed f when f.off_start && has_start && not reloaded ->
      Some (reload_why f)
  | Passed | Failed _ -> None

let stays_off (f : failure) ~has_start =
  Failed
    {
      f with
      repeats = true;
      reason =
        (if has_start then "off its start after a reload: " ^ f.reason
         else f.reason);
    }

(* The engine's rule over [tried] (oldest first), the off-start attempts
   left out. *)
let by_retries ~retries ~last tried =
  match Trials.attempts ~retries (List.map attempt_of tried) with
  | Trials.Attempt_again -> Again "a failure a reload may fix: trying again"
  | Run_passed -> Ended Passed
  | Run_failed _ when List.length tried = 1 -> Ended last
  | Run_failed { at; repeats; why } ->
      let last_reason = match last with Failed f -> f.reason | Passed -> "" in
      (* "failed the same way on all 3 attempts: <reason>" names it already. *)
      let reason =
        if String.ends_with ~suffix:last_reason why then why
        else why ^ ": " ^ last_reason
      in
      Ended (Failed { at; reason; repeats; off_start = false })

let next ~has_start ~retries ~reloaded ~last tried =
  match (reload_off_start ~has_start ~reloaded last, last) with
  | Some why, _ -> Again why
  | None, Failed f when f.off_start -> Ended (stays_off f ~has_start)
  | None, _ ->
      by_retries ~retries:(if has_start then retries else 0) ~last tried

let run ~has_start ~retries ~reload_first ~log attempt =
  let rec go n ~reload tried =
    let last = attempt ~attempt:n ~reload in
    let counted =
      if reload_off_start ~has_start ~reloaded:reload last = None then
        tried @ [ last ]
      else tried
    in
    match next ~has_start ~retries ~reloaded:reload ~last counted with
    | Ended outcome -> outcome
    | Again why ->
        log why;
        go (n + 1) ~reload:true counted
  in
  go 1 ~reload:reload_first []
