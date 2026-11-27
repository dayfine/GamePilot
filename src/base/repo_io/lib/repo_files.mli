(** Finding a file of the repo (an asset under [src/games/pokemon/frlg/assets/],
    a submodule's file) by its path from the repo root, wherever the program or
    test runs from inside the repo or from a packaged release archive, and
    resolving per-user GamePilot data directories across Unix and Windows. *)

val locate_in : roots:string list -> string -> string option
(** [locate_in ~roots path]: the first [root/path] that exists across [roots] in
    order. *)

val locate : string -> string option
(** The first [dir/path] that exists, trying the working directory and each
    parent, then [$GAMEPILOT_DATA], then [<exe_dir>/data] and
    [<parent_of_exe_dir>/data] (packaged release layouts). *)

val default_daemon : unit -> string
(** The default path to [gamepilot_daemon]: [$GAMEPILOT_DAEMON] when non-empty,
    else [<exe_dir>/bin/gamepilot_daemon] or [<exe_dir>/gamepilot_daemon] (with
    [.exe] on Windows) when present, else ["daemon/build/gamepilot_daemon"]. *)

val data_dir : string -> string -> string
(** [data_dir var name]: the value of environment variable [var] when non-empty,
    else [<home>/.local/share/gamepilot/<name>], where [<home>] is [$HOME], then
    [$USERPROFILE] (Windows), then ["."]. *)
