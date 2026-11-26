(** The PLZA readers' find templates ({!Plza_readers.Blob_assets}), read from
    the repo's assets folder and uploaded to the daemon, for a program's
    attempts on the series ({!Checkpoint_series}): plza.autostory's and
    plza.claim-gifts'. Moved from plza.autostory's series when plza.claim-gifts
    came. *)

val upload : unit -> (Plza_readers.Blob_assets.t, string) result
(** Each template uploaded: its hash; [Error] when the folder or a file is
    missing. *)
