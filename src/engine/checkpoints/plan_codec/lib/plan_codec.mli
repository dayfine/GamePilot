(** How a game's plans write its rules ({!Engine_rules.GAME_RULES}): the readers
    {!Plan_decode} calls for a pose, one of the game's actions and a promise.
    Only plan decoding uses them; the runner and the checks never see JSON.

    Every reader takes [where], the prefix of the object's fields
    (["f: checkpoint.events[2].args."]), as {!Json_field} readers do, and
    returns an [Error] naming the field. *)

(** A game's plan readers, over its rules [T]. *)
module type PLAN_CODEC = sig
  module T : Engine_rules.GAME_RULES

  val pose_of_plan : where:string -> Json_field.obj -> (T.Pose.t, string) result
  (** A [start] or [declared_after] object. *)

  val action_of_plan :
    string ->
    (where:string -> Json_field.obj -> (T.Action.t, string) result) option
  (** The reader of the game's action of that [kind], given the event's [args]
      (unknown args are its errors), or [None] when the name is not one of the
      game's. *)

  val postconditions_of_plan :
    where:string -> Json_field.obj -> (T.Postconditions.t, string) result
  (** A [postconditions] or [until] object. *)
end
