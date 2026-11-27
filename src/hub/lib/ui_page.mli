(** Static web assets for the local [gamepilot ui] control hub, loaded from
    [src/hub/web/] (or [<exe_dir>/data/src/hub/web/] in packaged releases) via
    {!Repo_io.Repo_files.locate}. *)

val index_html : unit -> (string, string) result
(** Contents of [src/hub/web/index.html]. *)

val style_css : unit -> (string, string) result
(** Contents of [src/hub/web/style.css]. *)

val app_js : unit -> (string, string) result
(** Contents of [src/hub/web/app.js]. *)
