(** How Pokémon's rules ({!Pokemon_rules}) read in log lines, failures and a
    plan's text. *)

include Engine_text.Rules_text.TEXT with module T = Pokemon_rules

module Pose_text = Pose_text
(** {!Pose_text}: poses as text. *)

module Kind_text = Kind_text
(** {!Kind_text}: the Pokémon kinds as text. *)

module Postconditions_text = Postconditions_text
(** {!Postconditions_text}: the promises as text. *)
