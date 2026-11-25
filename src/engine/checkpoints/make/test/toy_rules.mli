(** A toy game's rules for the engine's tests, built from the engine's pieces: a
    zone pose, the engine's story actions beside two toy sets (a walk; an inn's
    rest and buy), and a position with the toy's promises. Pure: its plan codec
    ({!Toy_codec}), text ({!Toy_text}) and kept reads ({!Toy_saved}) are their
    own modules. *)

module Toy_walk = Toy_walk
(** The toy's walk set. *)

module Toy_inn = Toy_inn
(** The toy's inn set. *)

module Toy_promises = Toy_promises
(** The toy's promises: gold and flags. *)

module Pose = Engine_rules.Zone_pose
(** Where the player stands: a zone. *)

(** The toy's actions: one constructor per set. *)
module Action : sig
  type t =
    | Story of Engine_rules.Story_action.t  (** The engine's. *)
    | Walk of Toy_walk.t  (** Hold a direction until a landmark shows. *)
    | Inn of Toy_inn.t  (** Rest at an inn, or buy there. *)

  include Engine_rules.ACTION with type t := t
end

(** What a toy checkpoint promises: an end zone, gold and flags. *)
module Postconditions :
  Engine_rules.POSTCONDITIONS
    with type t = (Pose.t, Toy_promises.t) Engine_rules.Promises.with_position
     and type reads = Toy_promises.reads

val ends_at : Action.t -> Pose.t option
(** [None]: a toy walk ends at a landmark, not at a zone it names. *)

val position : Postconditions.t -> Pose.t option
(** The promised end zone. *)
