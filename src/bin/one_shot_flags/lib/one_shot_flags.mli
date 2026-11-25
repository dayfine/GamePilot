(** [gamepilot run <one-shot program>]'s flags: a checkpoint run's (Run_flags,
    the same parser) with the program's own [--state PATH] and [--console].

    With [--watch] (or [--watch-port], [--listen]) the program runs in its own
    daemon, as a checkpoint run does: a checkpoint run's backend (mGBA through
    the bridge on [--mgba-port], or [--backend switch]), its page listed on the
    hub. Without, it runs on a daemon already up on [--port] (47900 unless
    given), and the flags that start a daemon are refused; so are a checkpoint
    series' own ([--from], [--mode], ...). *)

type own_daemon = {
  build : string;  (** The daemon's build (--daemon). *)
  backend : Daemon_process.backend;
  backend_name : string;  (** run.json's: mgba or switch. *)
  daemon_flags : string list;
      (** --viewport (the program's), --record, --keepawake, --speed. *)
  port : int;  (** The program's; 0: any free one. *)
  watch : Daemon_process.watch;
}
(** The daemon the program starts. *)

(** On a daemon already up on a port, or one of its own. *)
type daemon = Attach of int | Start of own_daemon

type t = {
  runs_dir : string;
  state : string option;
      (** The save state the program loads first: the program's default,
          --state's, or none (--console, the Switch). *)
  daemon : daemon;
}

val parse :
  Program_registry.t ->
  default_state:string ->
  string list ->
  (t, string) result
(** The flags given for the program, which loads [default_state] unless they say
    otherwise. Reads no files and starts nothing. *)

val start :
  own_daemon ->
  runs_dir:string ->
  Run_record.t ->
  label:string ->
  (Daemon_process.t, string) result
(** The daemon, started with its wire log and output in the run's folder; its
    page listed in the registry beside [runs_dir], the hub (127.0.0.1:47901)
    started if none runs, and the page's URLs printed. [label]: the run's name
    on the page. *)
