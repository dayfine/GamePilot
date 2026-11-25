(** The checkpoint engine over Pokémon: its rules ({!Pokemon_rules}), read from
    plans by {!Pokemon_plan_codec}, printed by {!Pokemon_text} and kept beside
    an event's state by {!Pokemon_saved}. The plans, handlers, runner, failures,
    event states and repeats every Pokémon game uses, with grid poses, Pokémon
    kinds and Pokémon promises in their types, and those rules' own modules
    beside them. *)

include module type of struct
  include
    Engine_checkpoints.Make (Pokemon_rules) (Pokemon_plan_codec) (Pokemon_text)
      (Pokemon_saved)
end

module Pose = Pokemon_rules.Pose
(** {!Pokemon_rules.Pose}: where a plan says the player stands, and where
    FireRed reads them. *)

module Own_kind = Pokemon_rules.Own_kind
(** {!Pokemon_rules.Own_kind}: the Pokémon event kinds. *)

module Postconditions = Pokemon_rules.Postconditions
(** {!Pokemon_rules.Postconditions}: what a Pokémon checkpoint promises. *)

module Postcondition_check = Pokemon_rules.Postcondition_check
(** {!Pokemon_rules.Postcondition_check}: those promises checked against what
    the game read. *)

module Pose_text = Pokemon_text.Pose_text
(** {!Pokemon_text.Pose_text}: poses as text. *)

module Postconditions_text = Pokemon_text.Postconditions_text
(** {!Pokemon_text.Postconditions_text}: the promises as text. *)

module Saved = Pokemon_saved
(** {!Pokemon_saved}: what a run keeps beside an event's save state. *)
