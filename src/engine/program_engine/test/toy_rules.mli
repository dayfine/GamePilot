(** A toy game's rules for the engine's tests, built from the engine's pieces: a
    zone pose, the engine's story actions beside two toy sets (a walk; an inn's
    rest and buy), and a position with the toy's promises. Pure, and each part
    prints itself; its plan format ({!Toy_plan_format}) and kept reads
    ({!Toy_event_snapshot}) are their own modules. *)

module Toy_walk = Toy_walk
(** The toy's walk set. *)

module Toy_inn = Toy_inn
(** The toy's inn set. *)

module Toy_promises = Toy_promises
(** The toy's promises: gold, flags and a sign in sight. *)

module Pose = Engine_rules.Zone_pose
(** Where the player stands: a zone. *)

(** The toy's actions: one constructor per set. *)
module Action : sig
  type t =
    | Story of Engine_rules.Builtin_action.t  (** The engine's. *)
    | Walk of Toy_walk.t  (** Hold a direction until a landmark shows. *)
    | Inn of Toy_inn.t  (** Rest at an inn, or buy there. *)

  include Engine_rules.ACTION with type t := t
end

(** What a toy checkpoint promises: an end zone, gold, flags and a sign. *)
module Postconditions :
  Engine_rules.POSTCONDITIONS
    with type t = (Pose.t, Toy_promises.t) Engine_rules.Promises.with_position
     and type reads = Toy_promises.reads

val ends_at : Action.t -> Pose.t option
(** [None]: a toy walk ends at a landmark, not at a zone it names. *)

val position : Postconditions.t -> Pose.t option
(** The promised end zone. *)

val end_place : Postconditions.t -> Postconditions.t option
(** The promised sign alone, the toy's end place (not its gold, a change, nor
    its flags); [None] when it promises none. *)
