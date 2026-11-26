(** A program's plan folder: its checkpoints (<ID>.plan.json) in run order, a
    range of them, and the one before an id. Whatever rules the plans are
    written over. *)

val plan_suffix : string
(** [".plan.json"]. *)

val checkpoint_ids : string -> (string list, string) result
(** Checkpoint ids in the folder, in run order ({!Checkpoint_order.compare}: a
    lettered part first). *)

val drop_until : string -> string list -> string list
(** The ids from this one on; [] when it is not there. *)

val select :
  string list ->
  from_id:string ->
  to_id:string ->
  (string list * string option, string) result
(** [from_id .. to_id] and the id after [to_id], if any. *)

val plan_file : plan_dir:string -> string -> string
(** The plan file of a checkpoint id in the folder. *)

val previous : string list -> string -> string option
(** The id before this one in the list's order, if any. *)
