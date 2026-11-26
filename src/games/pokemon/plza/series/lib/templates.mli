(** The PLZA readers' find templates ({!Plza_readers.Blob_assets}), read from
    the repo's assets folder and uploaded to the daemon, for a program's
    attempts on the series ({!Checkpoint_series}): plza.autostory's and
    plza.claim-gifts'. Moved from plza.autostory's series when plza.claim-gifts
    came. *)

val upload : unit -> (Plza_readers.Blob_assets.t, string) result
(** Each template uploaded: its hash; [Error] when the folder or a file is
    missing. *)

val upload_home_title : unit -> (Effects.template_hash, string) result
(** PLZA's title on the Switch's HOME
    ({!Plza_readers.Switch_home_tile.title_template}), uploaded for
    plza.autostory's 00.00-new-game launch; [Error] when it is not found from
    here. *)
