(** How a toy plan writes the toy's rules ({!Toy_rules}): the engine's zone
    pose, the toy's action sum from its parts, and the position with the toy's
    promises. *)

module Walk_decode :
  Engine_plan_codec.Action_parts.ACTION_DECODE
    with type t = Toy_rules.Toy_walk.t
(** The toy's [walk]. *)

module Inn_decode :
  Engine_plan_codec.Action_parts.ACTION_DECODE with type t = Toy_rules.Toy_inn.t
(** The toy's [rest] and [buy]. *)

val parts : Toy_rules.Action.t Engine_plan_codec.Action_parts.part list
(** The story set, the walk and the inn, each with its constructor. *)

include Engine_plan_codec.Plan_codec.PLAN_CODEC with module T = Toy_rules
