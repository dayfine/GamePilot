(** [gamepilot checkpoints PLAN_DIR --preflight --from ID]: the pre-flight of a
    save (Frlg_checkpoints.Preflight). Back to the last save, then what the
    first checkpoint's plan needs and the place read and printed as a table, in
    a run folder of its own ("<ID>-preflight"), run as a shadow plan
    (Frlg_checkpoints.Shadow_plan) through the checkpoint runner. *)

type setup = {
  states : string;
  runs_dir : string;
  daemon : string;
  backend : Daemon_process.backend;
  viewport : string option;
      (** The Switch daemon's --viewport: the program's
          (Program_registry.check_viewport). *)
  info : Run_record.info;
  watch : Daemon_process.watch option;
}

exception Not_back of string
(** The save could not be reloaded (raised by {!reload}). *)

val reload : setup -> string -> (string -> unit) -> unit
(** Back to what the save holds for checkpoint [id]: its start state on mGBA,
    the soft reset on the Switch. In the effect context; raises {!Not_back}. *)

val run : plan_dir:string -> from_id:string -> setup -> (int, string) result
(** The pre-flight of checkpoint [from_id]; exit code 1 on a mismatch or a need
    not read. *)
