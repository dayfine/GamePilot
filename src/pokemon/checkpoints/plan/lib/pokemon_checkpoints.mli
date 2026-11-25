(** The checkpoint engine over Pokémon's terms ({!Pokemon_terms}): the plans,
    handlers, runner, failures, event states and repeats every Pokémon game
    uses, with grid poses, Pokémon kinds and Pokémon promises in their types,
    and those terms' own modules beside them. *)

include module type of struct
  include Engine_checkpoints.Make (Pokemon_terms)
end

module Pose = Pokemon_terms.Pose
(** {!Pokemon_terms.Pose}: where a plan says the player stands, and where
    FireRed reads them. *)

module Own_kind = Pokemon_terms.Own_kind
(** {!Pokemon_terms.Own_kind}: the Pokémon event kinds. *)

module Postconditions = Pokemon_terms.Postconditions
(** {!Pokemon_terms.Postconditions}: what a Pokémon checkpoint promises. *)

module Postcondition_check = Pokemon_terms.Postcondition_check
(** {!Pokemon_terms.Postcondition_check}: those promises checked against what
    the game read. *)
