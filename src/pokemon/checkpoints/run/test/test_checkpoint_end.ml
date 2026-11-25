(* Checkpoint_end names where a checkpoint ends. *)

open Pokemon_checkpoints
open Checkpoints_run

(* A checkpoint starting at [start] (a pose's JSON), with one talk event. *)
let starting_at start =
  let text =
    Printf.sprintf
      {|{"format": "gamepilot-checkpoint/1", "game": "test", "execution": {},
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

let cases : Table_test.case list =
  [
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

let () = Table_test.run "checkpoint_end" cases
