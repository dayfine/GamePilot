(** [gamepilot checkpoints]' flags, whatever the game: their record, defaults
    and parsing. Each game's series runner reads them; a game's own flags
    (['game], e.g. Pokemon_flags.series) ride along, parsed by the game's hooks
    ({!game_flags}). *)

open Engine_run

type 'game flags = {
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
  max_rounds : int option;  (** A repeating checkpoint's rounds, at most. *)
  from_event : string option;
      (** mGBA, testing: run from this event's kept state
          (Engine_run.Event_range). *)
  to_event : string option;  (** ... to this event (else the last). *)
  port : int;  (** The program's port; 0: any free one. *)
  watch : Daemon_process.watch option;
  viewport : string option;
      (** --viewport V: the Switch daemons' game picture; only for a plan folder
          no program registers, else it must match the program's
          (Program_registry.check_viewport). *)
  daemon_flags : string list;
      (** --record, --no-record, --keepawake N, --speed S: passed to each run's
          daemon. *)
  options : (string * string) list;
      (** --options KEY=VALUE[,KEY=VALUE...]: the program's own options, in the
          order given; [[]] when not given. Their keys and values are the
          program's to check ({!read_options}). *)
  game : 'game;  (** The game's own flags. *)
}

type 'game game_flags = {
  game_defaults : 'game;
  game_switch : 'game -> string -> 'game option;
  game_valued : 'game -> string -> string -> ('game, string) result option;
}
(** How a game's own flags parse: their defaults, a flag without a value
    ([None]: not the game's), and a flag with its value ([None]: not the game's;
    [Some (Error _)]: a bad value). *)

type 'options option_keys = {
  unset : 'options;  (** No option given. *)
  keys : (string * ('options -> string -> ('options, string) result)) list;
      (** Each key the program takes, with how it reads its value: [Error] is
          the program's refusal of a bad value, as ["look is 1 to 8, not 9"]. *)
}
(** The keys a program takes in [--options] and how it reads them: the program's
    declaration, which {!read_options} checks the pairs against. *)

val no_option_keys : unit option_keys
(** A program that takes no options. *)

val read_options :
  'options option_keys -> (string * string) list -> ('options, string) result
(** The pairs of [--options] ({!flags.options}) read in order by the program's
    keys over [unset]; [Error] on a key it does not take (naming those it takes,
    or saying it takes none) or on a value its key refuses (prefixed
    ["--options "]). *)

val options_usage : string
(** [--options]' line in [gamepilot checkpoints]' usage, for every program:
    where to find each program's keys. *)

val data_dir : string -> string -> string
(** [data_dir var name]: [$var], else [$HOME/.local/share/gamepilot/<name>]. *)

val defaults : 'game game_flags -> 'game flags
(** $GAMEPILOT_STATES and $GAMEPILOT_RUNS (else under
    [$HOME/.local/share/gamepilot]), the daemon's build, mGBA's bridge port, no
    watch page, any free program port, saving after a pass on the Switch; the
    game's defaults. *)

val parse :
  'game game_flags -> 'game flags -> string list -> ('game flags, string) result
(** The flags given over [flags], the game's through its hooks; [Error] on an
    unknown flag or a bad value. --watch-port and --listen imply --watch. *)

val required : string -> 'a option -> ('a, string) result
(** The flag's value; ["NAME is required"] without it. *)

val daemon_backend :
  'game flags ->
  Checkpoint_trials.mode ->
  (Daemon_process.backend, string) result
(** The daemon's backend from the flags: mGBA, or the Switch (testing mode only)
    on --serial and --capture, or a dry run on --replay alone. *)
