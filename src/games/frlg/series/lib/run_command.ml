(* gamepilot run PROGRAM|DIR/PLANS --from ID --to ID --mode testing|verification
     [--runs N] [--states DIR] [--runs-dir DIR] [--daemon PATH]
     [--mgba-port N] [--port N] [--party SPECIES,...] [--center TOWN] [--walk]
     [--end-check-only] [--grind-battles N] [--watch] [--watch-port N]
     [--listen ADDR] [--backend mgba|switch --serial PORT --capture DEVICE]

   The checkpoint dev loop. A program's checkpoints are its plan files
   (<ID>.plan.json in the plan folder, in name order; --program ID in its place:
   Programs_command); each runs from its start state (<states>/<ID>.start.ss),
   as many times as the mode's policy says (Engine_run.Checkpoint_trials), each run with its own daemon and run folder
   (Run_record). A run passes when every event passed and the player ends at
   the checkpoint's declared end (Checkpoint_end) and the plan's
   postconditions hold (Pokemon_engine.Postcondition_check). With --end-check-only each
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

   A repeating checkpoint (its plan's metadata.repeat: 05-grind-mr-mime, the grind
   round) runs round after round, each one run with its attempts, each passing
   round saved (on the Switch in the game, on mGBA as the next round's start
   state), until its goal (repeat.until), read after each passing round,
   holds; then the series goes on. A round's failure soft-resets to the last
   round's save. --max-rounds N runs at most N rounds in place of the plan's
   repeat.max_rounds; with --grind-battles, reaching it passes.

   --options KEY=VALUE (one pair each, repeatable): the program's own choices,
   checked against its registry entry before anything runs
   (Program_registry.check_options), written in each run's run.json and the
   series record (the watch page's run header), and handed to its game actions
   (Frlg_actions.Checkpoint_game.config).

   --record/--no-record, --keepawake SECONDS: each run's daemon's (Watch-Page.md).
   --speed S (mGBA): the daemon steps the emulator S times as fast; waits and
   timeouts stay game time.
   --backend switch runs on the Switch (docs/switch-bring-up.md): the daemon
   drives the controller board on --serial and reads the capture card
   --capture (gamepilot switch-devices prints the lab's); --replay VIDEO
   alone, without --serial, is a dry run on the daemon's fake board. The
   game's own save is the start, so there are no start states and only --mode
   testing runs: before each run the runner soft-resets to the last save and
   checks the start; a run that passes is saved in the game
   (--save-after-pass, the default; --no-save-after-pass), a failed one
   soft-resets back to the last save (Checkpoints_series.Console_runs, Console_session).

   Each run reads the party from the members' summaries before its first
   action that finds a member by its species, so a save whose other members
   differ keeps every slot right; --party only states the first checkpoint's
   party for the Switch's start check when no checkpoint before it promises
   one.

   --make-room MAP (the save's map) runs the generated checkpoint 00-make-room first
   when the chain needs party room (Make_room_command).

   --from-event ID|N [--to-event ID|N] (mGBA, testing, one checkpoint: --to
   is --from unless given) runs that checkpoint from the save state kept at
   the event's start (Pokemon_engine.Event_snapshot: every mGBA run keeps one at each
   event it reaches cleanly) to the given event or the last, the end checks
   only when it runs the last. Its mode is "from-event" (run.json's
   from_event and to_event): it never verifies the checkpoint nor saves its
   end as the next start. The Switch has no save states: refused there.

   --preflight --from ID reads, from the save, what checkpoint ID's plan needs
   and prints a table (Preflight_command), its own run; exit 1 on a mismatch.

   --states defaults to $GAMEPILOT_STATES and --runs-dir to $GAMEPILOT_RUNS,
   else to $HOME/.local/share/gamepilot/{states,runs}.

   Mirrors, on the fork's frlg/lean (SerialPrograms/Source/Pokemon/AutoStory/):
   the start and end checkpoint range (Options/Pokemon_StoryRangeOptions.h)
   and the engine's run over it (Engine/Pokemon_StoryEngine.cpp); the
   verification loop (Engine/Pokemon_StoryVerifyRuns.cpp) for the runs of one
   checkpoint; the program leaving the game where it failed
   (PokemonFRLG_AutoStory.cpp), here as failure.ss. Not ported yet: retries
   inside a run (a checkpoint's attempts with a reload between,
   Engine/Pokemon_StoryEngine.cpp), the reproduction phase, the overlay log. mGBA itself is
   started and closed around the command by run/run_checkpoints_on_mgba.sh. *)

open Engine_run
include Run_flags

(* What the registry says of the program (Run_command.mli). *)
type program = {
  fields : string -> (string * string) list;
  viewport : (string option, string) result;
  options : Run_options.t;
}

let ( let* ) = Result.bind

(* What each run's run.json says of the series (or the pre-flight). *)
let run_info program plan_dir f kind ~from_id ~to_id : Run_record.info =
  {
    kind;
    program = program.fields plan_dir;
    from_id;
    to_id;
    backend = f.backend;
    options = Run_options.pairs program.options;
  }

let watch_of f =
  Watch_hub.for_runs_dir ~daemon:f.daemon ~runs_dir:f.runs_dir f.watch

(* The pre-flight's (and --make-room's party read's) setup. *)
let preflight_setup program plan_dir f backend ~viewport ~from_id :
    Preflight_command.setup =
  let info = run_info program plan_dir f Preflight ~from_id ~to_id:from_id in
  let { states; runs_dir; daemon; _ } = f in
  { states; runs_dir; daemon; backend; viewport; info; watch = watch_of f }

(* --from-event: testing by default, one checkpoint (--to is --from unless
   given). *)
let mode_and_to f ~from_id =
  match f.from_event with
  | None ->
      let* to_id = required "--to" f.to_id in
      let* mode = required "--mode" f.mode in
      Ok (mode, to_id)
  | Some _ ->
      Ok
        ( Option.value f.mode ~default:Checkpoint_trials.Testing,
          Option.value f.to_id ~default:from_id )

(* A partial run's own rules (Engine_run.Event_range.check). *)
let check_from_event f mode ~checkpoints =
  match f.from_event with
  | None -> Ok ()
  | Some _ ->
      Event_range.check ~mode ~keeps_states:(f.backend = "mgba") ~checkpoints

(* Each run's daemon: the program's --viewport, then the user's flags. *)
let daemons f backend ~viewport series =
  Series_daemons.create ~daemon:f.daemon ~backend ~port:f.port
    ~flags:(Daemon_process.viewport_args backend viewport @ f.daemon_flags)
    ~watch:(watch_of f) series

let from_event f = Option.map (fun first -> (first, f.to_event)) f.from_event

let run_series program plan_dir (f : Pokemon_flags.flags) =
  let* from_id = required "--from" f.from_id in
  let* mode, to_id = mode_and_to f ~from_id in
  let* () = check_from_event f mode ~checkpoints:1 in
  let* backend = daemon_backend f mode in
  let* viewport = program.viewport in
  let* plan_dir, from_id =
    Make_room_command.with_room ~plan_dir ~from_id f.game.make_room
      (preflight_setup program plan_dir f backend ~viewport ~from_id)
  in
  let* policy = Checkpoint_trials.policy ?runs:f.runs mode in
  let* ids = Plan_dir.checkpoint_ids plan_dir in
  let* selected, after = Plan_dir.select ids ~from_id ~to_id in
  let* () = check_from_event f mode ~checkpoints:(List.length selected) in
  let* world = Frlg_checkpoints.Checkpoint_run.load_world () in
  let info = run_info program plan_dir f Checkpoints ~from_id ~to_id in
  let mode_name = Checkpoint_trials.mode_to_string mode in
  let series : Series_daemons.series =
    { info; mode = mode_name; checkpoints = selected }
  in
  Ok
    (Checkpoint_series.run ~plan_dir
       {
         states = f.states;
         runs_dir = f.runs_dir;
         backend;
         common = { f.game.common with port = f.port };
         mode;
         policy;
         world;
         info;
         program_options = program.options;
         daemons = daemons f backend ~viewport series;
         save_after_pass = f.save_after_pass;
         max_rounds = f.max_rounds;
         from_event = from_event f;
       }
       selected ~after)

let preflight program plan_dir f =
  let* from_id = required "--from" f.from_id in
  let* backend = daemon_backend f Checkpoint_trials.Testing in
  let* viewport = program.viewport in
  Preflight_command.run ~plan_dir ~from_id
    (preflight_setup program plan_dir f backend ~viewport ~from_id)

(* A program over the Pokémon grid rules (Checkpoint_families): its
   preflight, or its series. *)
let run_grid ~program plan_dir f =
  if f.preflight then preflight program plan_dir f
  else run_series program plan_dir f
