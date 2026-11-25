(** The checkpoint engine over Pokémon: its rules ({!Pokemon_rules}), read from
    plans by {!Pokemon_plan_format}, printed by {!Pokemon_text} and kept beside
    an event's state by {!Pokemon_event_snapshot}. The plans, handlers, runner,
    failures, event states and repeats every Pokémon game uses, with grid poses,
    Pokémon actions and Pokémon promises in their types, and those rules' own
    modules beside them. *)

include module type of struct
  include
    Program_engine.Make (Pokemon_rules) (Pokemon_plan_format) (Pokemon_text)
      (Pokemon_event_snapshot)
end

module Pose = Pokemon_rules.Pose
(** {!Pokemon_rules.Pose}: where a plan says the player stands, and where
    FireRed reads them. *)

module Pokemon_action = Pokemon_rules.Pokemon_action
(** {!Pokemon_rules.Pokemon_action}: the Pokémon actions. *)

module Postconditions = Pokemon_rules.Postconditions
(** {!Pokemon_rules.Postconditions}: what a Pokémon checkpoint promises. *)

module Postcondition_check = Pokemon_rules.Postcondition_check
(** {!Pokemon_rules.Postcondition_check}: those promises checked against what
    the game read. *)

module Pose_text = Pokemon_text.Pose_text
(** {!Pokemon_text.Pose_text}: poses as text. *)

module Postconditions_text = Pokemon_text.Postconditions_text
(** {!Pokemon_text.Postconditions_text}: the promises as text. *)

module Saved = Pokemon_event_snapshot
(** {!Pokemon_event_snapshot}: what a run keeps beside an event's save state. *)
