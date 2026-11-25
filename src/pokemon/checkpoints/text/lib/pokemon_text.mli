(** How Pokémon's rules ({!Pokemon_rules}) read in log lines, failures and a
    plan's text. *)

include Engine_text.Rules_text.TEXT with module T = Pokemon_rules

module Pose_text = Pose_text
(** {!Pose_text}: poses as text. *)

module Pokemon_action_text = Pokemon_action_text
(** {!Pokemon_action_text}: the Pokémon actions as text. *)

module Postconditions_text = Postconditions_text
(** {!Postconditions_text}: the promises as text. *)
