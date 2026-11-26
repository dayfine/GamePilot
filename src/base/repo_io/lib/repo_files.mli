(** Finding a file of the repo (an asset under [src/games/pokemon/frlg/assets/],
    a submodule's file) by its path from the repo root, wherever the program or
    test runs from inside the repo, and resolving per-user GamePilot data
    directories across Unix and Windows. *)

val locate : string -> string option
(** The first [dir/path] that exists, trying the working directory and then each
    parent. *)

val data_dir : string -> string -> string
(** [data_dir var name]: the value of environment variable [var] when non-empty,
    else [<home>/.local/share/gamepilot/<name>], where [<home>] is [$HOME], then
    [$USERPROFILE] (Windows), then ["."]. *)
