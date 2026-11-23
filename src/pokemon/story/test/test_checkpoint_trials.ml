(* Checkpoint_trials decides, after each run of a checkpoint, whether to run it
   again, pass it or stop; Checkpoint_end names where a checkpoint ends. *)

open Story
open Checkpoint_trials

let policy_of ?runs mode =
  match policy ?runs mode with Ok p -> p | Error e -> failwith e

let verdict_text mode runs =
  match verdict (policy_of mode) runs with
  | Run_again -> "run again"
  | Checkpoint_passed { passes; runs } ->
      Printf.sprintf "passed %d/%d" passes runs
  | Stopped why -> "stopped: " ^ why

let fail at = Failed { at; repeats = false }

(* A checkpoint starting at [start] (a pose's JSON), with one talk event. *)
let starting_at start =
  let text =
    Printf.sprintf
      {|{"format": "pokesim-authored-checkpoint/1", "game": "test", "execution": {},
         "checkpoint": {"id": "next", "title": "test", "start": %s,
           "events": [{"id": "x", "kind": "talk"}]}}|}
      start
  in
  match Plan_decode.decode ~source:"inline" (Yojson.Safe.from_string text) with
  | Ok plan -> plan.checkpoint
  | Error message -> failwith message

let end_of ?next events =
  match
    Checkpoint_end.declared ~next (Plan_files.checkpoint_of_events events)
  with
  | Some pose -> Pose.grid_to_string pose
  | None -> "none"

let route_to_door =
  {|{"id": "to_door", "kind": "route", "args": {"target": {"map": "Town", "tiles": [[4, 0]]}}}|}

let cases : Case_table.case list =
  [
    {
      name = "verification: 2 of 3 passes the checkpoint";
      input =
        (fun () -> verdict_text Verification [ Passed; fail "#2 talk"; Passed ]);
      expectation = "passed 2/3";
    };
    {
      name =
        "verification: runs all 3 even after 2 passes, as verify_checkpoint()";
      input = (fun () -> verdict_text Verification [ Passed; Passed ]);
      expectation = "run again";
    };
    {
      name = "verification: 1 of 3 stops";
      input =
        (fun () ->
          verdict_text Verification [ fail "#1 walk"; Passed; fail "#2 talk" ]);
      expectation = "stopped: 1 of 3 runs passed, 2 needed";
    };
    {
      name = "the same step failing twice in a row is a hard stop";
      input =
        (fun () -> verdict_text Verification [ fail "#2 talk"; fail "#2 talk" ]);
      expectation = "stopped: hard stop: failed twice in a row at #2 talk";
    };
    {
      name = "a failure that repeats stops at once";
      input =
        (fun () ->
          verdict_text Verification
            [ Failed { at = "#1 walk"; repeats = true } ]);
      expectation = "stopped: the failure repeats: #1 walk";
    };
    {
      name = "testing: one run, one pass";
      input = (fun () -> verdict_text Testing [ Passed ]);
      expectation = "passed 1/1";
    };
    {
      name = "verification with fewer runs than passes needed is refused";
      input =
        (fun () ->
          match policy ~runs:1 Verification with Ok _ -> "ok" | Error e -> e);
      expectation = "verification needs 2 passes, so at least 2 runs";
    };
    {
      name = "the end is the next checkpoint's start";
      input =
        (fun () ->
          end_of [ route_to_door ]
            ~next:
              (starting_at
                 {|{"map": "Road", "tiles": [[1, 2]], "facing": "south"}|}));
      expectation = "Road (1, 2) south";
    };
    {
      name = "the last checkpoint ends at its last route's target";
      input = (fun () -> end_of [ route_to_door ]);
      expectation = "Town (4, 0)";
    };
    {
      name = "a last event with no pose declares no end";
      input = (fun () -> end_of [ {|{"id": "x", "kind": "talk"}|} ]);
      expectation = "none";
    };
  ]

let () = Case_table.run "checkpoint_trials" cases
