(** How a plan writes Pokémon's rules ({!Pokemon_rules}): poses
    ({!Pose_decode}), the Pokémon actions ({!Pokemon_action_decode}) and the
    postconditions ({!Postcondition_decode}, {!Party_decode}), for the engine's
    plan decoder. *)

include Engine_plan_codec.Plan_codec.PLAN_CODEC with module T = Pokemon_rules
