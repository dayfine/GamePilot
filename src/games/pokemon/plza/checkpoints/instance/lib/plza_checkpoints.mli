(** The checkpoint engine over PLZA: its rules ({!Plza_terms}), read from plans
    by {!Plza_plan_codec}, printed by {!Plza_text} and kept beside an event's
    state by {!Plza_saved}. The plans, handlers, runner, failures, event states
    and repeats PLZA's programs use, with zones and walks in their types. *)

include module type of struct
  include
    Engine_checkpoints.Make (Plza_terms) (Plza_plan_codec) (Plza_text)
      (Plza_saved)
end

module Pose = Plza_terms.Pose
(** {!Plza_terms.Pose}: zones. *)

module Walk_args = Plza_terms.Walk_args
(** {!Plza_terms.Walk_args}: a walk's legs and end. *)

module Saved = Plza_saved
(** {!Plza_saved}: what a run keeps beside an event's state. *)
