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
(** [from_id .. to_id] and the id after [to_id], if any. Either bound may be an
    id's leading part when one id alone starts with it and a dash: ["03.10"]
    names ["03.10-fourth-species"]; ["03.1"] names nothing. *)

type selection = {
  from_id : string;  (** The resolved starting checkpoint id. *)
  to_id : string;  (** The resolved ending checkpoint id. *)
  selected : string list;
      (** The checkpoints from [from_id] through [to_id], in run order. *)
  after : string option;
      (** The checkpoint id immediately after [to_id] in the folder, if any. *)
  all : string list;  (** All checkpoint ids in the folder, in run order. *)
}
(** A resolved checkpoint range selected from a plan folder. *)

val select_range :
  plan_dir:string ->
  from_id:string ->
  to_id:string ->
  (selection, string) result
(** Reads the folder's checkpoints ({!checkpoint_ids}), resolves [from_id] and
    [to_id] ({!resolve}), and returns the selected range ({!select}) together
    with the resolved bounds, the id after the range, and all ids in run order.
*)

val resolve : string list -> string -> (string, string) result
(** The id named: itself when listed, else the one id that starts with it and a
    dash; an error when none or more than one does. *)

val plan_file : plan_dir:string -> string -> string
(** The plan file of a checkpoint id in the folder. *)

val previous : string list -> string -> string option
(** The id before this one in the list's order, if any. *)

val load_all :
  load:(plan_dir:string -> string -> ('a, string) result) ->
  plan_dir:string ->
  string list ->
  ('a list, string) result
(** Loads each checkpoint id in [ids] from [plan_dir] in order via [load],
    stopping at the first [Error]. *)
