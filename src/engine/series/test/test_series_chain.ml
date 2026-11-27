(* Series_chain tracks continuing-from-pass state across checkpoints, trials,
   rounds, and attempts. Fakes are pure callbacks that record the contexts they
   receive and return scripted pass/fail outcomes. *)

open Engine_run
open Engine_series
module S = Series_chain

let check_eq name ~show ~expected ~actual =
  Table_test.report name
    (if actual = expected then Ok ()
     else
       Error
         (Printf.sprintf "expected %s, got %s" (show expected) (show actual)))

let show_bool = string_of_bool
let show_opt = function None -> "None" | Some s -> Printf.sprintf "Some %S" s

let show_item (it : string S.item) =
  Printf.sprintf "{value=%S; next=%s; continuing_from_pass=%b}" it.value
    (show_opt it.next) it.continuing_from_pass

let show_list f l = "[" ^ String.concat "; " (List.map f l) ^ "]"

let show_trial_at (n, attempt, at_start) =
  Printf.sprintf "(trial=%d, attempt=%d, already_at_start=%b)" n attempt
    at_start

let show_verdict = function
  | Checkpoint_trials.Run_again -> "Run_again"
  | Checkpoint_passed { passes; runs } ->
      Printf.sprintf "Checkpoint_passed {passes=%d; runs=%d}" passes runs
  | Stopped why -> Printf.sprintf "Stopped %S" why

let () =
  (* already_at_start predicate *)
  check_eq "cold start (first checkpoint): not already at start" ~show:show_bool
    ~expected:false
    ~actual:(S.already_at_start ~continuing_from_pass:false ~trial:1 ~attempt:1);
  check_eq "continuing from pass, trial 1, attempt 1: already at start"
    ~show:show_bool ~expected:true
    ~actual:(S.already_at_start ~continuing_from_pass:true ~trial:1 ~attempt:1);
  check_eq "retry after failure (attempt 2): not already at start"
    ~show:show_bool ~expected:false
    ~actual:(S.already_at_start ~continuing_from_pass:true ~trial:1 ~attempt:2);
  check_eq "verification repeat (trial 2): not already at start" ~show:show_bool
    ~expected:false
    ~actual:(S.already_at_start ~continuing_from_pass:true ~trial:2 ~attempt:1);
  check_eq "cold start verification repeat (trial 2): not already at start"
    ~show:show_bool ~expected:false
    ~actual:(S.already_at_start ~continuing_from_pass:false ~trial:2 ~attempt:1);

  (* run_round_trial *)
  let cold_round = S.run_round_trial ~continuing_from_pass:false in
  let cont_round = S.run_round_trial ~continuing_from_pass:true in
  check_eq "round 1 on cold start: not already at start" ~show:show_bool
    ~expected:false
    ~actual:(S.trial_already_at_start cold_round ~attempt:1);
  check_eq "round continuing from pass, attempt 1: already at start"
    ~show:show_bool ~expected:true
    ~actual:(S.trial_already_at_start cont_round ~attempt:1);
  check_eq "round continuing from pass, retry attempt 2: not already at start"
    ~show:show_bool ~expected:false
    ~actual:(S.trial_already_at_start cont_round ~attempt:2);

  (* run_chain: empty *)
  let seen = ref [] in
  let ok =
    S.run_chain [] (fun it ->
        seen := it :: !seen;
        true)
  in
  check_eq "empty chain returns true" ~show:show_bool ~expected:true ~actual:ok;
  check_eq "empty chain visits nothing" ~show:(show_list show_item) ~expected:[]
    ~actual:(List.rev !seen);

  (* run_chain: all pass with ~after *)
  let seen = ref [] in
  let ok =
    S.run_chain ~after:"04" [ "01"; "02"; "03" ] (fun it ->
        seen := it :: !seen;
        true)
  in
  check_eq "passing chain returns true" ~show:show_bool ~expected:true
    ~actual:ok;
  check_eq "passing chain tracks continuing_from_pass and next"
    ~show:(show_list show_item)
    ~expected:
      [
        { value = "01"; next = Some "02"; continuing_from_pass = false };
        { value = "02"; next = Some "03"; continuing_from_pass = true };
        { value = "03"; next = Some "04"; continuing_from_pass = true };
      ]
    ~actual:(List.rev !seen);

  (* run_chain: stops on failure *)
  let seen = ref [] in
  let ok =
    S.run_chain [ "01"; "02"; "03" ] (fun it ->
        seen := it :: !seen;
        it.value <> "02")
  in
  check_eq "failing chain returns false" ~show:show_bool ~expected:false
    ~actual:ok;
  check_eq "failing chain stops before remaining items"
    ~show:(show_list show_item)
    ~expected:
      [
        { value = "01"; next = Some "02"; continuing_from_pass = false };
        { value = "02"; next = Some "03"; continuing_from_pass = true };
      ]
    ~actual:(List.rev !seen);

  (* run_trials: verification policy with continuing_from_pass = true *)
  let policy =
    match Checkpoint_trials.policy Verification with
    | Ok p -> p
    | Error e -> failwith e
  in
  let seen = ref [] in
  let verdict, _ =
    S.run_trials policy ~continuing_from_pass:true ~trial:Fun.id (fun t ->
        (* Simulate attempt 1 on every trial, plus a retry attempt 2 on trial 1. *)
        let a1 = S.trial_already_at_start t ~attempt:1 in
        seen := (t.number, 1, a1) :: !seen;
        if t.number = 1 then
          seen := (t.number, 2, S.trial_already_at_start t ~attempt:2) :: !seen;
        Ok Checkpoint_trials.Passed)
  in
  check_eq "verification trials pass" ~show:show_verdict
    ~expected:(Checkpoint_passed { passes = 3; runs = 3 })
    ~actual:verdict;
  check_eq "verification trials: only trial 1 attempt 1 is already at start"
    ~show:(show_list show_trial_at)
    ~expected:[ (1, 1, true); (1, 2, false); (2, 1, false); (3, 1, false) ]
    ~actual:(List.rev !seen);

  (* run_trials: error stops early *)
  let seen = ref [] in
  let verdict, _ =
    S.run_trials policy ~continuing_from_pass:false ~trial:Fun.id (fun t ->
        seen := (t.number, 1, S.trial_already_at_start t ~attempt:1) :: !seen;
        if t.number = 2 then Error "no folder" else Ok Checkpoint_trials.Passed)
  in
  check_eq "trial error stops policy" ~show:show_verdict
    ~expected:(Stopped "no folder") ~actual:verdict;
  check_eq "trial error stops before trial 3" ~show:(show_list show_trial_at)
    ~expected:[ (1, 1, false); (2, 1, false) ]
    ~actual:(List.rev !seen);

  Table_test.finish ()
