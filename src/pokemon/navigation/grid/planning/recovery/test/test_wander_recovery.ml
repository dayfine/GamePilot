(* Wander decisions over a run of stops, one game's policy per case, with the
   waits spent after each stop. Ported from the C++ fork's
   Pokemon_WanderRecovery_Tests.cpp. *)

open Grid_recovery
open Wander_recovery

(* A stop and the decision expected for it. *)
type call =
  | Wall of wall_stop * wall_action option
  | Mid_leg of mid_leg_stop * mid_leg_action option
  | Unmoved of bool * unmoved_action option

type step = { fresh_leg : bool; call : call; waits_used : int }
type case = { name : string; policy : policy; steps : step list }

let step ?(fresh_leg = false) call waits_used = { fresh_leg; call; waits_used }

let wall ~zone ~probed expected =
  Wall ({ touches_wander_zone = zone; probed_person = probed }, expected)

let mid_leg ~ahead ~resume expected =
  Mid_leg ({ wanderer_ahead = ahead; can_resume_remaining = resume }, expected)

(* Whether the decision for [call] is the expected one, and the state after. *)
let decide policy state = function
  | Wall (stop, expected) ->
      let action, state = decide_wall policy state stop in
      (action = expected, state)
  | Mid_leg (stop, expected) ->
      let action, state = decide_mid_leg policy state stop in
      (action = expected, state)
  | Unmoved (blocked_by_wanderer, expected) ->
      let action, state = decide_unmoved policy state ~blocked_by_wanderer in
      (action = expected, state)

let run case =
  let rec go index state = function
    | [] -> Ok ()
    | step :: rest ->
        let state = if step.fresh_leg then fresh else state in
        let matched, state = decide case.policy state step.call in
        if matched && state.waits_used = step.waits_used then
          go (index + 1) state rest
        else
          Error
            (Printf.sprintf "step %d: decision %s, %d waits used (expected %d)"
               index
               (if matched then "as expected" else "differs")
               state.waits_used step.waits_used)
  in
  go 0 fresh case.steps

let frlg =
  {
    name = "FRLG policy";
    policy = { max_waits = 4; wait_ms = 1500; probe_with_a = false };
    steps =
      [
        step (wall ~zone:false ~probed:false None) 0;
        step (wall ~zone:true ~probed:false (Some Wait_and_rehold)) 1;
        step (wall ~zone:true ~probed:false (Some Wait_and_rehold)) 2;
        step (wall ~zone:true ~probed:false (Some Wait_and_rehold)) 3;
        step (wall ~zone:true ~probed:false (Some Wait_and_rehold)) 4;
        step (wall ~zone:true ~probed:false None) 4;
        step ~fresh_leg:true (mid_leg ~ahead:false ~resume:true None) 0;
        step
          (mid_leg ~ahead:true ~resume:true (Some Wait_and_resume_remaining))
          1;
        step (mid_leg ~ahead:true ~resume:false (Some Wait_and_reanchor)) 2;
        step (Unmoved (false, None)) 2;
        step (Unmoved (true, Some Wait_and_retry)) 3;
        step (Unmoved (true, Some Wait_and_retry)) 4;
        step (Unmoved (true, None)) 4;
        step (mid_leg ~ahead:true ~resume:true None) 4;
      ];
  }

let bdsp =
  {
    name = "BDSP policy";
    policy = { max_waits = 2; wait_ms = 500; probe_with_a = true };
    steps =
      [
        step (wall ~zone:true ~probed:false None) 0;
        step (wall ~zone:true ~probed:true (Some Wait_and_rehold)) 1;
        step (wall ~zone:true ~probed:true (Some Wait_and_rehold)) 2;
        step (wall ~zone:true ~probed:true (Some Replan_before_zone)) 2;
        step ~fresh_leg:true
          (mid_leg ~ahead:true ~resume:true (Some Wait_and_resume_remaining))
          1;
        step (Unmoved (true, Some Wait_and_retry)) 2;
        step (Unmoved (true, None)) 2;
      ];
  }

let () =
  List.iter (fun case -> Table_test.report case.name (run case)) [ frlg; bdsp ];
  Table_test.finish ()
