(** The PLZA readers' find templates ({!Plza_readers.Blob_assets}), read from
    the repo's assets folder and uploaded to the daemon, for the series' runs
    ({!Runs}). *)

val upload : unit -> (Plza_readers.Blob_assets.t, string) result
(** Each template uploaded: its hash; [Error] when the folder or a file is
    missing. *)
