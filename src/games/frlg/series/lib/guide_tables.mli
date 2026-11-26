(** FRLG's blocks of a program's user guide page (Guide_page, bin's
    Guide_blocks): each checkpoint's row, what the save must hold for a chain,
    and what the pre-flight checks before each checkpoint. Each takes the plan
    folder and the checkpoint ids the block names. *)

val rows : plan_dir:string -> string list -> (string list, string) result
(** One table row per checkpoint: its id and its plan's title, a repeating one
    marked. *)

val needs : plan_dir:string -> string list -> (string, string) result
(** What the save must hold for the chain: its free party slots
    (Frlg_checkpoints.Party_room) and the pre-flight's needs
    (Frlg_checkpoints.Preflight.needs, the checkpoint before's promises
    included) of the chain's events taken as one plan, one line each. *)

val preflight : plan_dir:string -> string list -> (string, string) result
(** A table: per checkpoint, what the pre-flight checks before a run resumed
    there. *)
