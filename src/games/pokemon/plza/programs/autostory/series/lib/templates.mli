(** The PLZA readers' find templates ({!Plza_readers.Blob_assets}), read from
    the repo's assets folder and uploaded to the daemon, for the series' runs
    ({!Runs}). *)

val upload : unit -> (Plza_readers.Blob_assets.t, string) result
(** Each template uploaded: its hash; [Error] when the folder or a file is
    missing. *)

val upload_home_title : unit -> (Effects.template_hash, string) result
(** PLZA's title on the Switch's HOME
    ({!Plza_readers.Switch_home_tile.title_template}), uploaded for
    00.00-new-game's launch; [Error] when it is not found from here. *)
