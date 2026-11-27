(** How BDSP's plans write {!Bdsp_rules}: zones
    ({!Engine_plan_format.Zone_pose_decode}), BDSP's own event kinds, and empty
    postconditions. *)

include Engine_plan_format.Plan_format.PLAN_FORMAT with module T = Bdsp_rules
