(** Process lifecycle, log capture, and one-run-per-console locking for runs
    dispatched by [gamepilot ui], combined with {!External_runs} detection. *)

type t
(** Mutable hub run table bound to one [consoles.json] path. *)

val create : config_path:string -> t
(** Creates an empty run manager for [config_path]. *)

val config_path : t -> string
(** Returns the [consoles.json] path configured on the manager. *)

val reap_all : t -> unit
(** Drains stdout/stderr pipes and reaps any exited child processes. *)

val detect_external : unit -> External_runs.t list
(** Scans the host process table for external [gamepilot] / [gamepilot_daemon]
    runs and resolves their watch URLs from daemon registries. *)

val active_for_console :
  t -> External_runs.t list -> Console_config.console -> Yojson.Safe.t option
(** Returns the active run JSON for a console (hub-launched or external), if
    any. *)

val all_runs_json : t -> Yojson.Safe.t
(** JSON payload for [GET /api/runs], combining hub runs and detected external
    runs. *)

val spawn : t -> Ui_api.launch_request -> (Yojson.Safe.t, int * string) result
(** Validates console availability and program options, then launches
    [gamepilot run ...] as a child process. Returns [Error (http_code, msg)] on
    conflict or bad input. *)

val stop : t -> string -> (Yojson.Safe.t, int * string) result
(** Sends [SIGTERM] to a hub-launched run and any child [gamepilot_daemon]
    holding its console's serial/mGBA port so the console is freed immediately.
*)
