(** A decoded plan as text, one line per thing, so a test can compare it with
    what the plan file says. The game's poses, kinds and promises are printed by
    its text ({!Rules_text.TEXT}). *)

(** The game's plans as text. *)
module Make
    (T : Engine_rules.GAME_RULES)
    (_ : Rules_text.TEXT with module T = T) : sig
  val pose : T.Pose.t -> string
  (** {!Rules_text.TEXT.pose}: ["CeladonCity (48, 12) south"]. *)

  val kind :
    Engine_plan.Plan.Make(T)(Engine_plan_format.Raw_json).kind -> string
  (** The kind with its typed args: ["answer no"],
      ["route to Town (4, 0) north"]. *)

  val kind_name :
    Engine_plan.Plan.Make(T)(Engine_plan_format.Raw_json).kind -> string
  (** The kind's name in the plan format: ["route"], ["game_action"], ... *)

  val event :
    Engine_plan.Plan.Make(T)(Engine_plan_format.Raw_json).event -> string
  (** ["id: [action] kind => declared_after skip_if a,b once_per_save"], each
      part only when the event has it. *)

  val event_named :
    Engine_plan.Plan.Make(T)(Engine_plan_format.Raw_json).t -> string -> string
  (** The plan's event of that id as {!event}, or ["no event <id>"]. *)

  val outline :
    Engine_plan.Plan.Make(T)(Engine_plan_format.Raw_json).t -> string
  (** ["frlg 01-celadon-setup from CeladonCity (48, 12) south: 6 game_action, 7
       route"]: the plan's game, id, start, and how many events of each kind, in
      first-seen order. *)

  val postconditions :
    Engine_plan.Plan.Make(T)(Engine_plan_format.Raw_json).t -> string
  (** The plan's postconditions, one per line; ["none"] when it states none. *)

  val repeat : Engine_plan.Plan.Make(T)(Engine_plan_format.Raw_json).t -> string
  (** ["at most N rounds, until:"] and the goal's postconditions, or
      ["no repeat"]. *)
end
