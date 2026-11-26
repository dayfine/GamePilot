(** A PLZA series' plans as it runs them: each loaded and checked
    ({!Plza_autostory.Plan_check}) before the console moves, with its end place
    resolved ({!Plza_autostory.Start_signature.promised_end}: its
    postconditions' [place], else the next checkpoint's start signature in the
    folder's run order, as FireRed's end is the next checkpoint's start) and put
    in its postconditions, which the runner reads. *)

val load_plan : plan_dir:string -> string -> (Plza_engine.Plan.t, string) result
(** The plan [<plan_dir>/<id>.plan.json], decoded. *)

val load :
  plan_dir:string ->
  all:string list ->
  string list ->
  (Plza_engine.Plan.t list, string) result
(** [load ~plan_dir ~all ids]: the plans [ids] in order, [all] the folder's
    checkpoint ids in run order (for the one after the last of [ids]); the first
    error, naming its plan. *)
