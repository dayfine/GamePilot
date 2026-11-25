(** Pokémon's terms for the checkpoint engine ({!Engine_terms.GAME_TERMS}): a
    plan's pose is a tile pose (or a zone, decoded and never checked), the game
    reads the player on a map tile, the own kinds are the grid walks, battles,
    healing and shopping ({!Own_kind}), a checkpoint promises a party, items,
    coins, money, flags, moves, levels and marks ({!Postconditions}), and a run
    keeps the counts read at the checkpoint's start and the tile the player
    stood on beside an event's state. The family applies the engine to them
    once: [Pokemon_checkpoints]. *)

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
(** The Pokémon event kinds, as the engine reads and prints them. *)

(** What a Pokémon checkpoint promises, as the engine reads, checks and prints
    it. *)
module Promises :
  Engine_terms.PROMISES
    with type t = Postconditions.t
     and type reads = Postcondition_check.observed

(** What a Pokémon run keeps beside an event's save state, as
    [<n>-<event>.json]: [start_money], [start_coins], [start_items]
    ({!Postcondition_check.start_to_json}) and [at] ({!Pose.observed_to_json},
    or [null]). *)
module Saved : sig
  type t = {
    start : Postcondition_check.start;
        (** What the run read at the checkpoint's start for the promises of a
            change. *)
    at : Pose.observed option;  (** Where the player was reckoned to stand. *)
  }

  include Engine_terms.SAVED with type t := t
end
