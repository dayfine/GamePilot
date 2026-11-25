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

module Postcondition_check = Postcondition_check
(** {!Postcondition_check}: those promises checked against what the game read.
*)

module Kind : Engine_terms.KIND with type t = Own_kind.t
(** The Pokémon event kinds, as the engine reads and prints them. *)

(** {!Postconditions}: what a Pokémon checkpoint promises, read
    ({!Postcondition_decode}) and checked against what the game read
    ({!Postcondition_check}). *)
module Postconditions : sig
  include module type of struct
    include Postconditions
  end

  include
    Engine_terms.POSTCONDITIONS
      with type t := t
       and type reads = Postcondition_check.observed
end

(** What a Pokémon run keeps beside an event's save state, as
    [<n>-<event>.json]: [start_money] and [start_coins] (a number or [null]),
    [start_items] (an object of counts) and [at] ({!Pose.observed_to_yojson}, or
    [null]), derived ([[@@deriving yojson]]). A field left out reads as not
    read: a file kept before the coins and items were has only [start_money] and
    [at]. *)
module Saved : sig
  type t = {
    start : Postcondition_check.start;
        (** What the run read at the checkpoint's start for the promises of a
            change. *)
    at : Pose.observed option;  (** Where the player was reckoned to stand. *)
  }

  include Engine_terms.SAVED with type t := t
end
