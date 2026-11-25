(** How a log prints a zone pose ({!Engine_rules.Zone_pose}): ["Village/inn"],
    or the place alone. It is a {!With_position_text.POSE_TEXT}. *)

type t = Engine_rules.Zone_pose.t

val pose : t -> string
(** A plan's zone. *)

val observed : Engine_rules.Zone_pose.observed -> string
(** Where the player was read: as {!pose}. *)
