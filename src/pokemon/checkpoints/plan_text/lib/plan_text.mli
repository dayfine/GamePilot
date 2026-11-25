(** A decoded plan as text, one line per thing, so a test can compare it with
    what the plan file says. *)

val pose : Checkpoints_plan.Pose.grid -> string
(** ["CeladonCity (48, 12) south"]. *)

val declared : Checkpoints_plan.Pose.declared -> string
(** A grid pose as {!pose}, a zone as ["zone <place>"]. *)

val kind : Checkpoints_plan.Plan.kind -> string
(** The kind with its typed args: ["route to Town (4, 0) north"]. *)

val event : Checkpoints_plan.Plan.event -> string
(** ["id: [action] kind => declared_after skip_if a,b once_per_save"], each part
    only when the event has it. *)

val event_named : Checkpoints_plan.Plan.t -> string -> string
(** The plan's event of that id as {!event}, or ["no event <id>"]. *)

val kind_name : Checkpoints_plan.Plan.kind -> string
(** The kind's name in the plan format: ["route"], ["game_action"], ... *)

val outline : Checkpoints_plan.Plan.t -> string
(** ["frlg 01-celadon-setup from CeladonCity (48, 12) south: 6 game_action, 7
     route"]: the plan's game, id, start, and how many events of each kind, in
    first-seen order. *)

val postconditions : Checkpoints_plan.Plan.t -> string
(** The plan's postconditions, one per line; ["none"] when it states none. *)

val repeat : Checkpoints_plan.Plan.t -> string
(** ["at most N rounds, until:"] and the goal's postconditions, or
    ["no repeat"]. *)
