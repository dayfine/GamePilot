(* Chain_progress: what the watch page's Run strip shows as a fake chain
   (a, b, c) runs, one step per runner call. *)

open Story
module W = Wire.Watch_run

let policy_of ?runs mode =
  match Checkpoint_trials.policy ?runs mode with
  | Ok p -> p
  | Error e -> failwith e

let fail ?(repeats = false) at = Checkpoint_trials.Failed { at; repeats }

(* The chain at second 0, each step one second later. *)
type step =
  | Begin of string
  | Trial
  | End of Checkpoint_trials.run
  | Broken
  | Rounds of int  (** The current checkpoint repeats: at most N rounds. *)
  | Rounds_end of bool

let apply (t, now_ms) step =
  let now_ms = now_ms + 1000 in
  let t =
    match step with
    | Begin id -> Chain_progress.begin_checkpoint t id ~now_ms
    | Trial -> Chain_progress.begin_trial t
    | End run -> Chain_progress.end_trial t run ~now_ms
    | Broken -> Chain_progress.fail_checkpoint t ~now_ms
    | Rounds max_rounds -> Chain_progress.begin_rounds t ~max_rounds
    | Rounds_end passed -> Chain_progress.end_rounds t ~passed ~now_ms
  in
  (t, now_ms)

(* "a:passed:2s b:current:1s c:pending:0s | verification 2/3 1+ 0-" *)
let shown mode steps =
  let t0 =
    Chain_progress.create ~mode ~policy:(policy_of mode) ~started_ms:0
      [ "a"; "b"; "c" ]
  in
  let t, now_ms = List.fold_left apply (t0, 0) steps in
  let w = Chain_progress.to_wire t ~now_ms in
  let cp (c : W.checkpoint) =
    Printf.sprintf "%s:%s:%ds" c.id
      (W.string_of_state c.state)
      (c.elapsed_ms / 1000)
  in
  Printf.sprintf "%s | %s %d/%d %d+ %d-"
    (String.concat " " (List.map cp w.checkpoints))
    w.mode w.trial w.trials w.passes w.fails

let pass_once id = [ Begin id; Trial; End Passed ]
let t = Checkpoint_trials.Testing
let v = Checkpoint_trials.Verification
let round = [ Trial; End Passed ]

let cases : Table_test.case list =
  [
    {
      name = "a repeating checkpoint: each round is a trial, of at most N";
      input =
        (fun () ->
          shown t ([ Begin "a"; Rounds 20 ] @ round @ round @ [ Trial ]));
      expectation =
        "a:current:6s b:pending:0s c:pending:0s | testing 3/20 2+ 0-";
    };
    {
      name = "its rounds end when the runner says: the goal met";
      input =
        (fun () ->
          shown t ([ Begin "a"; Rounds 20 ] @ round @ [ Rounds_end true ]));
      expectation = "a:passed:4s b:pending:0s c:pending:0s | testing 1/20 1+ 0-";
    };
    {
      name = "a failed round fails the checkpoint, the rest skipped";
      input =
        (fun () ->
          shown t
            ([ Begin "a"; Rounds 20 ] @ round
            @ [ Trial; End (fail "#1 grind"); Rounds_end false ]));
      expectation = "a:failed:6s b:skipped:0s c:skipped:0s | testing 2/20 1+ 1-";
    };
    {
      name = "the next checkpoint is a plain one again";
      input =
        (fun () ->
          shown t
            ([ Begin "a"; Rounds 20 ] @ round @ [ Rounds_end true ]
           @ pass_once "b"));
      expectation = "a:passed:4s b:passed:2s c:pending:0s | testing 1/1 1+ 0-";
    };
    {
      name = "before the first checkpoint: all pending, no trial";
      input = (fun () -> shown t []);
      expectation = "a:pending:0s b:pending:0s c:pending:0s | testing 0/1 0+ 0-";
    };
    {
      name = "a run in progress counts as the trial, its time so far";
      input = (fun () -> shown t [ Begin "a"; Trial ]);
      expectation = "a:current:1s b:pending:0s c:pending:0s | testing 1/1 0+ 0-";
    };
    {
      name = "testing: a pass moves on, the next checkpoint starts over";
      input = (fun () -> shown t (pass_once "a" @ [ Begin "b"; Trial ]));
      expectation = "a:passed:2s b:current:1s c:pending:0s | testing 1/1 0+ 0-";
    };
    {
      name = "testing: a failure fails it and skips the rest";
      input =
        (fun () ->
          shown t (pass_once "a" @ [ Begin "b"; Trial; End (fail "#1 x") ]));
      expectation = "a:passed:2s b:failed:2s c:skipped:0s | testing 1/1 0+ 1-";
    };
    {
      name = "verification: a failure retries, the trial and counts go on";
      input = (fun () -> shown v [ Begin "a"; Trial; End (fail "#2 x"); Trial ]);
      expectation =
        "a:current:3s b:pending:0s c:pending:0s | verification 2/3 0+ 1-";
    };
    {
      name = "verification: 2 of 3 passes after the third run";
      input =
        (fun () ->
          shown v
            [
              Begin "a";
              Trial;
              End Passed;
              Trial;
              End (fail "#2 x");
              Trial;
              End Passed;
            ]);
      expectation =
        "a:passed:6s b:pending:0s c:pending:0s | verification 3/3 2+ 1-";
    };
    {
      name = "verification: two passes still run the third";
      input =
        (fun () -> shown v [ Begin "a"; Trial; End Passed; Trial; End Passed ]);
      expectation =
        "a:current:4s b:pending:0s c:pending:0s | verification 2/3 2+ 0-";
    };
    {
      name = "verification: the same step failing twice stops it";
      input =
        (fun () ->
          shown v
            [ Begin "a"; Trial; End (fail "#2 x"); Trial; End (fail "#2 x") ]);
      expectation =
        "a:failed:4s b:skipped:0s c:skipped:0s | verification 2/3 0+ 2-";
    };
    {
      name = "a repeating failure (Stop pressed) stops at once";
      input =
        (fun () ->
          shown v [ Begin "a"; Trial; End (fail ~repeats:true "#1 x") ]);
      expectation =
        "a:failed:2s b:skipped:0s c:skipped:0s | verification 1/3 0+ 1-";
    };
    {
      name = "a checkpoint that cannot start fails without a trial";
      input = (fun () -> shown t (pass_once "a" @ [ Begin "b"; Broken ]));
      expectation = "a:passed:2s b:failed:1s c:skipped:0s | testing 0/1 0+ 0-";
    };
  ]

let () = Table_test.run "chain_progress" cases
