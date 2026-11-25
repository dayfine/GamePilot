(** How a plan writes a zone pose ({!Engine_rules.Zone_pose}): an object with
    [place] and, optionally, [spot]. It is a
    {!With_position_decode.POSE_DECODE}. *)

type t = Engine_rules.Zone_pose.t

val pose_of_plan : where:string -> Json_field.obj -> (t, string) result
(** A [start], [declared_after] or [position] object; any other field is an
    error. *)
