(** [gamepilot checkpoints]' flags (each game's series runner reads them), their
    defaults and parsing, and [gamepilot checkpoint]'s, which a series' runs
    share. *)

open Engine_run

type checkpoint_flags = {
  state : string option;
  port : int;
  log_file : string option;
  party : string;
  center : string option;
  walk : bool;
  end_check_only : bool;
  grind_cap : int option;
}
(** [gamepilot checkpoint PLAN.json]'s flags; a series' runs take theirs from
    the series' (port 0 there: any free one). *)

val checkpoint_defaults : checkpoint_flags
(** No state, log or party; the program's default port; running. *)

type flags = {
  from_id : string option;
  to_id : string option;
  mode : Checkpoint_trials.mode option;
  runs : int option;
  states : string;
  runs_dir : string;
  daemon : string;
  mgba_port : int;
  backend : string;  (** mgba or switch *)
  serial : string option;
  capture : string option;
  replay : string option;  (** A recorded video for a dry run (fake board). *)
  save_after_pass : bool;  (** Switch: save in the game after a pass. *)
  preflight : bool;
  make_room : string option;  (** The save's map: room first (00-make-room). *)
  max_rounds : int option;  (** A repeating checkpoint's rounds, at most. *)
  from_event : string option;
      (** mGBA, testing: run from this event's kept state
          (Engine_run.Event_range). *)
  to_event : string option;  (** ... to this event (else the last). *)
  common : checkpoint_flags;
  watch : Daemon_process.watch option;
  viewport : string option;
      (** --viewport V: the Switch daemons' game picture; only for a plan folder
          no program registers, else it must match the program's
          (Program_registry.check_viewport). *)
  daemon_flags : string list;
      (** --record, --no-record, --keepawake N, --speed S: passed to each run's
          daemon. *)
}

val usage : string

val data_dir : string -> string -> string
(** [data_dir var name]: [$var], else [$HOME/.local/share/gamepilot/<name>]. *)

val defaults : flags
(** $GAMEPILOT_STATES and $GAMEPILOT_RUNS (else under
    [$HOME/.local/share/gamepilot]), the daemon's build, mGBA's bridge port, no
    watch page, saving after a pass on the Switch. *)

val parse : flags -> string list -> (flags, string) result
(** The flags given over [flags]; [Error] on an unknown flag or a bad value.
    --watch-port and --listen imply --watch. *)

val required : string -> 'a option -> ('a, string) result
(** The flag's value; ["NAME is required"] without it. *)

val daemon_backend :
  flags -> Checkpoint_trials.mode -> (Daemon_process.backend, string) result
(** The daemon's backend from the flags: mGBA, or the Switch (testing mode only)
    on --serial and --capture, or a dry run on --replay alone. *)
