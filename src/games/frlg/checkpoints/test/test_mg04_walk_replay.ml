(* Replays the first live FireRed run recorded through GamePilot: mg-04's first
   event, the walk from Lavender's Center to Pokemon Tower 5F (8, 9), which
   fled two wild battles and cleared the PurifiedZone message on the way.

   Re-record: daemon/build/gamepilot_daemon --backend mgba --mgba-port 47810
   --log run.wire.jsonl, then gamepilot checkpoint on 04-grind-farfetchd (mg-04 then) cut to its first
   event with --state mg04_start.ss (a save state, not committed); rewrite the
   load_state path in the log to "mg04_start.ss" (replay does not compare it)
   and gzip -9n it to mg04_walk_two_fled_battles.wire.jsonl.gz. *)

open Frlg_checkpoints

let wire_log = "mg04_walk_two_fled_battles.wire.jsonl"

(* The state path as the committed log names it. *)
let start_state = "mg04_start.ss"

(* 04-grind-farfetchd with only its first event, the walk the log recorded. *)
let walk_plan () =
  let p =
    Result.get_ok
      (Frlg_checkpoints.Plan_file.load "04-grind-farfetchd.plan.json")
  in
  let first = List.hd p.checkpoint.events in
  {
    p with
    checkpoint = { p.checkpoint with events = [ first ] };
    postconditions =
      {
        p.postconditions with
        party = None;
        money = None;
        items = [];
        knows = [];
        levels = [];
      };
  }

let fled line = String.starts_with ~prefix:"Wild battle: fled" line

(* The checkpoint's outcome under replay and how many wild battles it fled. *)
let replayed_walk () =
  let lines = ref [] in
  let options : Checkpoint_run.options =
    {
      state = Some start_state;
      party = Some (Frlg_actions.Party_roster.of_string "");
      center = None;
      grind_cap = None;
      gait = Running;
      end_check_only = false;
      log = (fun line -> lines := line :: !lines);
    }
  in
  let world = Result.get_ok (Checkpoint_run.load_world ()) in
  let outcome =
    match
      Replay.run (Replay.log_of_file wire_log) (fun () ->
          Checkpoint_run.run options world (walk_plan ()))
    with
    | Ok () -> "PASSED"
    | Error failure -> "FAILED " ^ Pokemon_checkpoints.Failure.to_string failure
    | exception Replay.Divergence e -> "DIVERGED " ^ e
  in
  Printf.sprintf "%s; fled %d wild battles" outcome
    (List.length (List.filter fled !lines))

let () =
  Table_test.run "mg04_walk_replay"
    [
      {
        name = "Lavender Center to Tower 5F, two wild battles fled";
        input = replayed_walk;
        expectation = "PASSED; fled 2 wild battles";
      };
    ]
