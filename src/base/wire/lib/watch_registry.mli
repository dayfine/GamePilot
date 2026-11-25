(** An entry of the watch registry: one JSON file per daemon serving a watch
    page, [$GAMEPILOT_RUNS/.watch/<pid>.json], written by the daemon while it
    lives (daemon/src/watch_registry.h) and read by [gamepilot runs]. A reader
    skips an entry whose pid is gone (a daemon that died without removing it).
*)

type json = Yojson.Safe.t
(** A decoded JSON value: one registry file, or a page's [/summary.json]. *)

type entry = {
  pid : int;  (** The daemon's process id, to tell whether it still lives. *)
  port : int;  (** The watch page's. *)
  listen : string;  (** The address the watch page is bound to ([--listen]). *)
  backend : string;  (** What it drives: ["mgba"], ["switch"] or ["view"]. *)
  run_folder : string;  (** Empty when none was given. *)
  checkpoint : string;  (** Empty when none was given. *)
  started_ms : int;  (** When the daemon started, Unix ms. *)
}
(** One daemon serving a watch page: who it is, where its page and its clients
    connect, what it drives and which run it belongs to. *)

val of_json : json -> entry
(** One registry file's entry; a missing or mistyped field is a [Decode_error].
*)

type summary = { run : Watch_run.t option; plan : Watch.plan option }
(** What a run's page has (its [/summary.json]): the latest [watch.run] and
    [watch.plan], each none until the program sent one. *)

val summary_of_json : json -> summary
(** A page's [/summary.json]; [run] and [plan] are each absent or [null] until
    the program sends one. *)
