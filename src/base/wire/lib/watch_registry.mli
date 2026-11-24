(** An entry of the watch registry: one JSON file per daemon serving a watch
    page, [$GAMEPILOT_RUNS/.watch/<pid>.json], written by the daemon while it
    lives (daemon/src/watch_registry.h) and read by [gamepilot runs]. A reader
    skips an entry whose pid is gone (a daemon that died without removing it).
*)

type json = Yojson.Safe.t

type entry = {
  pid : int;
  port : int;  (** The watch page's. *)
  listen : string;
  backend : string;
  run_folder : string;  (** Empty when none was given. *)
  checkpoint : string;  (** Empty when none was given. *)
  started_ms : int;  (** When the daemon started, Unix ms. *)
}

val of_json : json -> entry

type summary = { run : Watch_run.t option; plan : Watch.plan option }
(** What a run's page has (its [/summary.json]): the latest [watch.run] and
    [watch.plan], each none until the program sent one. *)

val summary_of_json : json -> summary
