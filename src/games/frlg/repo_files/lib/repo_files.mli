(** Finding a file of the repo (an asset under [src/games/frlg/assets/], a
    submodule's file) by its path from the repo root, wherever the program or
    test runs from inside the repo. *)

val locate : string -> string option
(** The first [dir/path] that exists, trying the working directory and then each
    parent. *)
