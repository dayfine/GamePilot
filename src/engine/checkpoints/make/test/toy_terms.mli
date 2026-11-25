(** A toy game's terms for the engine's tests: zones and no grid. *)

(** Where the player stands: a zone. *)
module Pose : sig
  type t = { place : string; spot : string option }
  (** A place, and maybe a spot in it. *)

  include Engine_terms.POSE with type t := t and type observed = t
end

(** The toy's own kinds. *)
module Kind : sig
  type t =
    | Walk of { toward : string; until : string }
        (** Hold a direction until a landmark shows. *)
    | Rest  (** Rest at an inn. *)

  include Engine_terms.KIND with type t := t
end

(** What a toy checkpoint promises. *)
module Promises : sig
  type t = { gold : Engine_promise.Count.t option; flags : string list }
  (** Gold gained since the start, and flags set. *)

  type reads = { gold_now : int option; start : int option; set : string list }
  (** The gold now and at the start, and the flags set. *)

  include Engine_terms.PROMISES with type t := t and type reads := reads
end

(** What a toy run keeps beside an event's state. *)
module Saved : sig
  type t = { start : int option; at : Pose.t option }
  (** The gold at the checkpoint's start, and where the player was reckoned to
      stand. *)

  include Engine_terms.SAVED with type t := t
end
