(** The checkpoint engine over PLZA: its rules ({!Plza_rules}), read from plans
    by {!Plza_plan_format}, printed by {!Plza_text} and kept beside an event's
    state by {!Plza_event_snapshot}. The plans, handlers, runner, failures,
    event states and repeats PLZA's programs use, with zones and walks in their
    types. *)

include module type of struct
  include
    Program_engine.Make (Plza_rules) (Plza_plan_format) (Plza_text)
      (Plza_event_snapshot)
end

module Pose = Plza_rules.Pose
(** {!Plza_rules.Pose}: zones. *)

module Walk_args = Plza_rules.Walk_args
(** {!Plza_rules.Walk_args}: a walk's legs and end. *)

module Saved = Plza_event_snapshot
(** {!Plza_event_snapshot}: what a run keeps beside an event's state. *)
