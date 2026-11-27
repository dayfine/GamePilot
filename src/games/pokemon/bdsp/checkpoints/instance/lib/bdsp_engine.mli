(** The checkpoint engine applied to BDSP's rules ({!Bdsp_rules}), plan format
    ({!Bdsp_plan_format}) and event snapshot ({!Bdsp_event_snapshot}). *)

include module type of
    Program_engine.Make (Bdsp_rules) (Bdsp_plan_format) (Bdsp_event_snapshot)

module Pose = Bdsp_rules.Pose
(** {!Bdsp_rules.Pose}: where the player stands. *)

module Saved = Bdsp_event_snapshot
(** {!Bdsp_event_snapshot}: what a run keeps beside an event's state. *)
