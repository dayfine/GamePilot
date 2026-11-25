(** How a toy plan writes the toy's rules ({!Toy_rules}). *)

include Engine_plan_codec.Plan_codec.PLAN_CODEC with module T = Toy_rules
