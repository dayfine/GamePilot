(** Detection of ongoing [gamepilot] and [gamepilot_daemon] runs started outside
    the UI hub (e.g. from a terminal or lab script), matched to configured
    consoles by serial port or mGBA bridge port. *)

type t = {
  pid : int;  (** Operating system process ID. *)
  program : string;
      (** Program or checkpoint name (e.g. ["bdsp.underground"]). *)
  serial : string option;  (** Switch serial port passed via [--serial]. *)
  mgba_port : int option;  (** mGBA bridge port passed via [--port]. *)
  registry : string option;  (** Daemon watch registry directory, if any. *)
  watch_url : string option;  (** Live watch page URL resolved from registry. *)
  run_folder : string option;
      (** Run folder path, if passed via [--run-folder]. *)
  command : string;  (** Full process command line. *)
}
(** An external GamePilot run discovered from the host process table. *)

val parse_ps_lines : string list -> t list
(** Pure parser for [ps -axo pid=,args=] output lines. Recognizes
    [gamepilot_daemon] (excluding [--hub]) and [gamepilot run] invocations. *)

val enrich_watch_url : t -> t
(** Resolves [watch_url] by reading [<registry>/<pid>.json] when [registry] is
    present and [watch_url] is not yet set. *)

val match_console : t list -> Console_config.console -> t option
(** Finds an external run holding the given console's serial port or mGBA port,
    preferring a [gamepilot_daemon] entry (which carries watch registry info).
*)

val to_json : console_id:string -> t -> Yojson.Safe.t
(** Encodes an external run in the same JSON shape as hub-launched runs, with
    ["external": true]. *)
