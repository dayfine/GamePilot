(** The hub (gamepilot_daemon --hub, docs/design/Watch-Page.md): the page at
    127.0.0.1:47901 listing the live runs from the watch registry. The runner
    starts it when nothing answers on its port; it runs in its own session, so
    it outlives the run, and one already running makes this a no-op. *)

val for_runs_dir :
  daemon:string ->
  runs_dir:string ->
  Daemon_process.watch option ->
  Daemon_process.watch option
(** A run's page, listed in the registry beside [runs_dir] (--runs-dir may come
    after --watch), with the hub started if none runs. *)
