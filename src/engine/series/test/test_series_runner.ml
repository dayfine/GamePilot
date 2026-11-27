(* Typed tests for Engine_series.Series_runner: chaining, prepare errors,
   trial policy, watch chain progress, on_pass hooks, and override hooks.
   Fakes are pure callbacks with a deterministic counter clock. *)

open Engine_run
open Engine_series
module R = Series_runner

type fake_plan = { id : string; note : string }
type fake_run = { trial_no : int; outcome : Checkpoint_trials.run }

let check_eq name ~show ~expected ~actual =
  Table_test.report name
    (if actual = expected then Ok ()
     else
       Error
         (Printf.sprintf "expected %s, got %s" (show expected) (show actual)))

let show_bool = string_of_bool
let show_opt = function None -> "None" | Some s -> Printf.sprintf "Some %S" s
let show_list f l = "[" ^ String.concat "; " (List.map f l) ^ "]"
let show_str s = Printf.sprintf "%S" s

let show_pass (id, next, trials) =
  Printf.sprintf "(%S, %s, %s)" id (show_opt next)
    (show_list string_of_int trials)

let show_trial_call (id, number, cont) =
  Printf.sprintf "(%S, trial=%d, cont=%b)" id number cont

let make_clock () =
  let t = ref 1000 in
  fun () ->
    t := !t + 100;
    !t

let policy_of mode =
  match Checkpoint_trials.policy mode with Ok p -> p | Error e -> failwith e

let () =
  (* 1. Empty series passes immediately. *)
  let logs = ref [] in
  let hooks : (string, fake_plan, fake_run) R.hooks =
    {
      entry_id = Fun.id;
      prepare = (fun id ~next:_ -> Ok { id; note = "" });
      run_trial = (fun _ _ ~progress:_ -> Ok { trial_no = 1; outcome = Passed });
      trial_of = (fun r -> r.outcome);
      verdict_note = (fun p -> p.note);
      on_pass = (fun _ ~next:_ _ -> ());
    }
  in
  let passed =
    R.run ~mode:Testing ~policy:(policy_of Testing) ~now_ms:(make_clock ())
      ~log:(fun l -> logs := l :: !logs)
      hooks []
  in
  check_eq "empty series returns true" ~show:show_bool ~expected:true
    ~actual:passed;
  check_eq "empty series logs nothing" ~show:(show_list show_str) ~expected:[]
    ~actual:(List.rev !logs);

  (* 2. Verification chain: 2 checkpoints with ~after, tracks continuing_from_pass,
     runs 3 trials each, passes verdict_note and on_pass runs, updates progress. *)
  let calls = ref [] in
  let passes = ref [] in
  let logs = ref [] in
  let last_wire = ref None in
  let hooks : (string, fake_plan, fake_run) R.hooks =
    {
      entry_id = Fun.id;
      prepare =
        (fun id ~next:_ ->
          Ok { id; note = (if id = "02" then " (capped)" else "") });
      run_trial =
        (fun plan (t : Series_chain.trial) ~progress ->
          calls := (plan.id, t.number, t.continuing_from_pass) :: !calls;
          let _before = progress None in
          let run = { trial_no = t.number; outcome = Passed } in
          last_wire := Some (progress (Some run.outcome));
          Ok run);
      trial_of = (fun r -> r.outcome);
      verdict_note = (fun p -> p.note);
      on_pass =
        (fun plan ~next runs ->
          passes :=
            (plan.id, next, List.map (fun r -> r.trial_no) runs) :: !passes);
    }
  in
  let passed =
    R.run ~mode:Verification ~policy:(policy_of Verification)
      ~now_ms:(make_clock ())
      ~log:(fun l -> logs := l :: !logs)
      ~after:"03" hooks [ "01"; "02" ]
  in
  check_eq "verification chain passes" ~show:show_bool ~expected:true
    ~actual:passed;
  check_eq "verification chain trial calls"
    ~show:(show_list show_trial_call)
    ~expected:
      [
        ("01", 1, false);
        ("01", 2, false);
        ("01", 3, false);
        ("02", 1, true);
        ("02", 2, true);
        ("02", 3, true);
      ]
    ~actual:(List.rev !calls);
  check_eq "verification chain on_pass records runs and next"
    ~show:(show_list show_pass)
    ~expected:[ ("01", Some "02", [ 1; 2; 3 ]); ("02", Some "03", [ 1; 2; 3 ]) ]
    ~actual:(List.rev !passes);
  check_eq "verification chain logs verdicts with notes"
    ~show:(show_list show_str)
    ~expected:
      [
        "[Checkpoints] 01: passed (3 of 3 runs)";
        "[Checkpoints] 02: passed (3 of 3 runs) (capped)";
      ]
    ~actual:(List.rev !logs);
  let final_states =
    match !last_wire with
    | None -> []
    | Some (w : Wire.Watch_run.t) ->
        List.map
          (fun (c : Wire.Watch_run.checkpoint) -> (c.id, c.state))
          w.checkpoints
  in
  let show_state (id, st) =
    let s =
      match st with
      | Wire.Watch_run.Pending -> "Pending"
      | Current -> "Current"
      | Passed -> "Passed"
      | Failed -> "Failed"
      | Skipped -> "Skipped"
    in
    Printf.sprintf "(%S, %s)" id s
  in
  check_eq "watch progress marks both checkpoints passed"
    ~show:(show_list show_state)
    ~expected:[ ("01", Wire.Watch_run.Passed); ("02", Wire.Watch_run.Passed) ]
    ~actual:final_states;

  (* 3. Prepare error stops chain and logs error without running remaining items. *)
  let seen = ref [] in
  let logs = ref [] in
  let hooks : (string, fake_plan, fake_run) R.hooks =
    {
      entry_id = Fun.id;
      prepare =
        (fun id ~next:_ ->
          seen := id :: !seen;
          if id = "02" then Error "missing state" else Ok { id; note = "" });
      run_trial =
        (fun _ t ~progress:_ -> Ok { trial_no = t.number; outcome = Passed });
      trial_of = (fun r -> r.outcome);
      verdict_note = (fun _ -> "");
      on_pass = (fun _ ~next:_ _ -> ());
    }
  in
  let passed =
    R.run ~mode:Testing ~policy:(policy_of Testing) ~now_ms:(make_clock ())
      ~log:(fun l -> logs := l :: !logs)
      hooks [ "01"; "02"; "03" ]
  in
  check_eq "prepare error returns false" ~show:show_bool ~expected:false
    ~actual:passed;
  check_eq "prepare error stops before 03" ~show:(show_list show_str)
    ~expected:[ "01"; "02" ] ~actual:(List.rev !seen);
  check_eq "prepare error logs checkpoint error" ~show:(show_list show_str)
    ~expected:
      [
        "[Checkpoints] 01: passed (1 of 1 runs)";
        "[Checkpoints] 02: missing state";
      ]
    ~actual:(List.rev !logs);

  (* 4. Trial returning Error stops trials and chain. *)
  let seen = ref [] in
  let passes = ref [] in
  let hooks : (string, fake_plan, fake_run) R.hooks =
    {
      entry_id = Fun.id;
      prepare = (fun id ~next:_ -> Ok { id; note = "" });
      run_trial =
        (fun plan _ ~progress:_ ->
          seen := plan.id :: !seen;
          Error "folder failed");
      trial_of = (fun r -> r.outcome);
      verdict_note = (fun _ -> "");
      on_pass = (fun plan ~next:_ _ -> passes := plan.id :: !passes);
    }
  in
  let passed =
    R.run ~mode:Testing ~policy:(policy_of Testing) ~now_ms:(make_clock ())
      ~log:(fun _ -> ())
      hooks [ "01"; "02" ]
  in
  check_eq "trial Error returns false" ~show:show_bool ~expected:false
    ~actual:passed;
  check_eq "trial Error does not run 02" ~show:(show_list show_str)
    ~expected:[ "01" ] ~actual:(List.rev !seen);
  check_eq "trial Error does not call on_pass" ~show:(show_list show_str)
    ~expected:[] ~actual:!passes;

  (* 5. Override hook handles matching checkpoints and falls back on None. *)
  let override_calls = ref [] in
  let standard_passes = ref [] in
  let hooks : (string, fake_plan, fake_run) R.hooks =
    {
      entry_id = Fun.id;
      prepare = (fun id ~next:_ -> Ok { id; note = "" });
      run_trial =
        (fun _ t ~progress:_ -> Ok { trial_no = t.number; outcome = Passed });
      trial_of = (fun r -> r.outcome);
      verdict_note = (fun _ -> "");
      on_pass =
        (fun plan ~next:_ _ -> standard_passes := plan.id :: !standard_passes);
    }
  in
  let override ~chain ~run_trial (plan : fake_plan) ~continuing_from_pass
      ~next:_ =
    if plan.id <> "02-repeat" then None
    else (
      chain := Chain_progress.begin_rounds !chain ~max_rounds:2;
      let res =
        run_trial plan { Series_chain.number = 1; continuing_from_pass }
      in
      let ok = Result.is_ok res in
      chain := Chain_progress.end_rounds !chain ~passed:ok ~now_ms:2000;
      override_calls := (plan.id, continuing_from_pass, ok) :: !override_calls;
      Some ok)
  in
  let passed =
    R.run ~mode:Testing ~policy:(policy_of Testing) ~now_ms:(make_clock ())
      ~log:(fun _ -> ())
      ~override hooks
      [ "01"; "02-repeat"; "03" ]
  in
  let show_override (id, cont, ok) = Printf.sprintf "(%S, %b, %b)" id cont ok in
  check_eq "override chain passes" ~show:show_bool ~expected:true ~actual:passed;
  check_eq "override invoked only for repeating checkpoint"
    ~show:(show_list show_override)
    ~expected:[ ("02-repeat", true, true) ]
    ~actual:!override_calls;
  check_eq "standard checkpoints still call on_pass" ~show:(show_list show_str)
    ~expected:[ "01"; "03" ]
    ~actual:(List.rev !standard_passes);

  Table_test.finish ()
