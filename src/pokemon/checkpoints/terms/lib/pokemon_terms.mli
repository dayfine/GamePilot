(** Pokémon's rules for the checkpoint engine ({!Engine_terms.TERMS}): a plan's
    pose is a tile pose (or a zone, never checked), the game reads the player on
    a map tile, the own kinds are the grid walks, battles, healing and shopping
    ({!Own_kind}), and a checkpoint promises a party, items, coins, money,
    flags, moves, levels and marks ({!Postconditions}), checked by
    {!Postcondition_check}. Pure: how a plan writes them is
    [Pokemon_plan_codec], how a log prints them [Pokemon_text], and what a run
    keeps [Pokemon_saved]. The family applies the engine to the four once:
    [Pokemon_checkpoints]. *)

(** {!Pose}: where a plan says the player stands (a tile pose, or a zone that
    holds wherever the player is), and where the game reads them. *)
module Pose : sig
  include module type of struct
    include Pose
  end

  include Engine_terms.POSE with type t = declared and type observed := observed
end

module Own_kind = Own_kind
(** {!Own_kind}: the Pokémon event kinds. *)

module Postconditions = Postconditions
(** {!Postconditions}: what a Pokémon checkpoint promises. *)

module Postcondition_check = Postcondition_check
(** {!Postcondition_check}: those promises checked against what the game read.
*)

module Kind : Engine_terms.KIND with type t = Own_kind.t
(** The Pokémon event kinds, as the engine carries them. *)

(** What a Pokémon checkpoint promises, as the engine checks it. *)
module Promises :
  Engine_terms.PROMISES
    with type t = Postconditions.t
     and type reads = Postcondition_check.observed
