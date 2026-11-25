(** Pokémon's rules for the checkpoint engine ({!Engine_rules.GAME_RULES}): a
    plan's pose is a tile pose (or a zone, never checked), the game reads the
    player on a map tile, its actions are the grid walks, battles, healing and
    shopping ({!Pokemon_action}), and a checkpoint promises a party, items,
    coins, money, flags, moves, levels and marks ({!Postconditions}), checked by
    {!Postcondition_check}. Pure, and each part prints itself: how a plan writes
    them is [Pokemon_plan_format], and what a run keeps
    [Pokemon_event_snapshot]. The family applies the engine to the three once:
    [Pokemon_engine]. *)

(** {!Pose}: where a plan says the player stands (a tile pose, or a zone that
    holds wherever the player is), and where the game reads them. *)
module Pose : sig
  include module type of struct
    include Pose
  end

  include Engine_rules.POSE with type t = declared and type observed := observed
end

module Pokemon_action = Pokemon_action
(** {!Pokemon_action}: the Pokémon actions, the game's event kinds. *)

module Postcondition_check = Postcondition_check
(** {!Postcondition_check}: those promises checked against what the game read.
*)

module Action : Engine_rules.ACTION with type t = Pokemon_action.t
(** The Pokémon actions, as the engine carries them. *)

(** {!Postconditions}: what a Pokémon checkpoint promises, and its check against
    what the game read ({!Postcondition_check}). *)
module Postconditions : sig
  include module type of struct
    include Postconditions
  end

  include
    Engine_rules.POSTCONDITIONS
      with type t := t
       and type reads = Postcondition_check.observed
end

val ends_at : Action.t -> Pose.t option
(** Where an action says it leaves the player: a [route]'s or [ready]'s target;
    [None] for every other action. *)

val position : Postconditions.t -> Pose.t option
(** The promised end [position], as a grid pose. *)
