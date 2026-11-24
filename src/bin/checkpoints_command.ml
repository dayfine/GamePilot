(* gamepilot checkpoints PLAN_DIR --from ID --to ID --mode testing|verification
     [--runs N] [--states DIR] [--runs-dir DIR] [--daemon PATH]
     [--mgba-port N] [--port N] [--party SPECIES,...] [--center TOWN] [--walk]
     [--end-check-only] [--grind-battles N] [--watch] [--watch-port N]
     [--listen ADDR] [--backend mgba|switch --serial PORT --capture DEVICE]

   The checkpoint dev loop. A program's checkpoints are its plan files
   (<ID>.plan.json in PLAN_DIR, in name order; --program ID in its place:
   Programs_command); each runs from its start state (<states>/<ID>.start.ss),
   as many times as the mode's policy says (Story.Checkpoint_trials), each run with its own daemon and run folder
   (Run_record). A run passes when every event passed and the player ends at
   the checkpoint's declared end (Story.Checkpoint_end) and the plan's
   postconditions hold (Story.Postcondition_check). With --end-check-only each
   run checks its start state against the postconditions and runs no event. The loop goes to the
   next checkpoint only after this one passed; in verification mode the last
   passing run's end becomes the next checkpoint's start state.

   --grind-battles N (testing) ends each grind, passing, after N battles: the
   run's summary says "grind capped at N" and which postconditions it skipped,
   and its end is never saved as the next checkpoint's start.

   --watch serves the run's watch page (the daemon's, docs/design/Watch-Page.md)
   on a free port (--watch-port fixes it), the same for every run of the
   series, lists it in the watch registry ($GAMEPILOT_RUNS/.watch) and starts
   the hub (Watch_hub, 127.0.0.1:47901) if none runs. --listen 0.0.0.0 (or
   $GAMEPILOT_WATCH_LISTEN) opens both to the LAN; Stop then takes the series'
   token, which the URL printed for other devices carries. The program's port
   (--port) is a free one too unless given, so runs do not collide.

   --record/--no-record, --keepawake SECONDS: each run's daemon's (Watch-Page.md).
   --backend switch runs on the Switch (docs/switch-bring-up.md): the daemon
   drives the controller board on --serial and reads the capture card
   --capture (gamepilot switch-devices prints the lab's); --replay VIDEO
   alone, without --serial, is a dry run on the daemon's fake board. The
   game's own save is the start, so there are no start states and only --mode
   testing runs: before each run the runner soft-resets to the last save and
   checks the start; a run that passes is saved in the game
   (--save-after-pass, the default; --no-save-after-pass), a failed one
   soft-resets back to the last save (Story.Console_runs, Console_session).

   Each run reads the party from the members' summaries before its first
   action that finds a member by its species, so a save whose other members
   differ keeps every slot right; --party only states the first checkpoint's
   party for the Switch's start check when no checkpoint before it promises
   one.

   --make-room MAP (the save's map) runs the generated checkpoint mg-00 first
   when the chain needs party room (Make_room_command).

   --preflight --from ID reads, from the save, what checkpoint ID's plan needs
   and prints a table (Preflight_command), its own run; exit 1 on a mismatch.

   --states defaults to $GAMEPILOT_STATES and --runs-dir to $GAMEPILOT_RUNS,
   else to $HOME/.local/share/gamepilot/{states,runs}.

   Mirrors, on the fork's frlg/lean (SerialPrograms/Source/Pokemon/AutoStory/):
   the START/END_CHECKPOINT range (Options/Pokemon_StoryRangeOptions.h) and
   StoryEngine::run_checkpoints() (Engine/Pokemon_StoryEngine.cpp) over it;
   verify_checkpoint() (Engine/Pokemon_StoryVerifyRuns.cpp) for the runs of
   one checkpoint; the program leaving the game where it failed
   (STORY_LEFT_WHERE_FAILED in PokemonFRLG_AutoStory.cpp), here as failure.ss.
   Not ported yet: retries inside a run (StoryGame::attempts_per_checkpoint
   with reload), the reproduction phase, the overlay log. mGBA itself is
   started and closed around the command by run/run_checkpoints_on_mgba.sh. *)

open Story
module R = Program_registry
include Checkpoints_flags

let ( let* ) = Result.bind

(* The daemon's backend from the flags; the Switch only in testing mode. *)
let daemon_backend f mode =
  match (f.backend, f.serial, f.capture, f.replay, mode) with
  | "mgba", None, None, None, _ ->
      Ok (Daemon_process.Mgba { port = f.mgba_port })
  | "mgba", _, _, _, _ ->
      Error "--serial, --capture and --replay need --backend switch"
  | "switch", _, _, _, Checkpoint_trials.Verification ->
      Error "--backend switch runs only --mode testing"
  | "switch", Some serial, Some capture, None, Testing ->
      Ok
        (Daemon_process.Switch
           { serial = Some serial; frames = Capture capture })
  | "switch", None, None, Some video, Testing ->
      Ok (Daemon_process.Switch { serial = None; frames = Replay video })
  | "switch", _, _, _, _ ->
      Error
        "--backend switch needs --serial and --capture, or --replay alone (a \
         dry run on the fake board)"
  | b, _, _, _, _ -> Error ("bad --backend " ^ b)

(* What each run's run.json says of the series (or the pre-flight). *)
let run_info plan_dir f kind ~from_id ~to_id : Run_record.info =
  let program = Attached_run.program_fields (R.of_plan_dir plan_dir) in
  { kind; program; from_id; to_id; backend = f.backend }

let watch_of f =
  Watch_hub.for_runs_dir ~daemon:f.daemon ~runs_dir:f.runs_dir f.watch

(* The pre-flight's (and --make-room's party read's) setup. *)
let preflight_setup plan_dir f backend ~from_id : Preflight_command.setup =
  let info = run_info plan_dir f Preflight ~from_id ~to_id:from_id in
  let { states; runs_dir; daemon; _ } = f in
  { states; runs_dir; daemon; backend; info; watch = watch_of f }

let run_series plan_dir f =
  let* from_id = required "--from" f.from_id in
  let* to_id = required "--to" f.to_id in
  let* mode = required "--mode" f.mode in
  let* backend = daemon_backend f mode in
  let* plan_dir, from_id =
    Make_room_command.with_room ~plan_dir ~from_id f.make_room
      (preflight_setup plan_dir f backend ~from_id)
  in
  let* policy = Checkpoint_trials.policy ?runs:f.runs mode in
  let* ids = Plan_dir.checkpoint_ids plan_dir in
  let* selected, after = Plan_dir.select ids ~from_id ~to_id in
  let* world = Frlg_story.Checkpoint_run.load_world () in
  Ok
    (Checkpoint_series.run ~plan_dir
       {
         states = f.states;
         runs_dir = f.runs_dir;
         daemon = f.daemon;
         backend;
         common = f.common;
         mode;
         policy;
         world;
         watch = watch_of f;
         info = run_info plan_dir f Checkpoints ~from_id ~to_id;
         daemon_flags = f.daemon_flags;
         bound = ref None;
         save_after_pass = f.save_after_pass;
       }
       selected ~after)

let preflight plan_dir f =
  let* from_id = required "--from" f.from_id in
  let* backend = daemon_backend f Checkpoint_trials.Testing in
  Preflight_command.run ~plan_dir ~from_id
    (preflight_setup plan_dir f backend ~from_id)

let main plan_dir args =
  let* f = parse defaults args in
  if f.preflight then preflight plan_dir f else run_series plan_dir f
