(** BDSP's rules for the checkpoint engine ({!Engine_rules.GAME_RULES}). Pure,
    and each part prints itself: how a plan writes them is {!Bdsp_plan_format},
    and what a run keeps {!Bdsp_event_snapshot}; {!Bdsp_engine} applies the
    engine to all three. *)

(** Where the player stands: a zone ({!Engine_rules.Zone_pose}). *)
module Pose :
  Engine_rules.POSE
    with type t = Engine_rules.Zone_pose.t
     and type observed = Engine_rules.Zone_pose.observed

(** BDSP's actions: its own event kinds. *)
module Action : sig
  (** One of BDSP's own checkpoint actions. *)
  type t = Save_game  (** Save the game in-game ([X -> R -> A]). *)

  include Engine_rules.ACTION with type t := t
end

(** What a BDSP checkpoint promises at its end (none yet). *)
module Postconditions :
  Engine_rules.POSTCONDITIONS with type t = unit and type reads = unit

val ends_at : Action.t -> Pose.t option
(** [None]: BDSP actions do not declare a grid target pose. *)

val position : Postconditions.t -> Pose.t option
(** [None]: BDSP promises no end zone. *)

val end_place : Postconditions.t -> Postconditions.t option
(** [None]: BDSP checks no end-place skip signature before running events. *)
