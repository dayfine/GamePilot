(** Pokémon's terms for the checkpoint engine ({!Engine_terms.GAME_TERMS}): a
    plan's pose is a tile pose (or a zone, decoded and never checked), the game
    reads the player on a map tile, the own kinds are the grid walks, battles,
    healing and shopping ({!Own_kind}), and a checkpoint promises a party,
    items, coins, money, flags, moves, levels and marks ({!Postconditions}). The
    family applies the engine to them once: [Pokemon_checkpoints]. *)

module Pose = Pose
(** {!Pose}: where a plan says the player stands, and where the game reads them.
*)

module Own_kind = Own_kind
(** {!Own_kind}: the Pokémon event kinds. *)

module Postconditions = Postconditions
(** {!Postconditions}: what a Pokémon checkpoint promises. *)

module Postcondition_check = Postcondition_check
(** {!Postcondition_check}: those promises checked against what the game read.
*)

include
  Engine_terms.GAME_TERMS
    with type pose = Pose.declared
     and type observed = Pose.observed
     and type own_kind = Own_kind.t
     and type promises = Postconditions.t
     and type reads = Postcondition_check.observed
     and type start_reads = Postcondition_check.start
