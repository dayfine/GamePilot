(** How a log prints promises with a position
    ({!Engine_rules.Promises.with_position}): [position <pose>] first, then the
    promises' lines in their own order. *)

(** The pose's text. *)
module type POSE_TEXT = sig
  type t

  val pose : t -> string
end

(** A set of promises' text. *)
module type PROMISES_TEXT = sig
  type t

  val postconditions : t -> string list
  (** One line per promise. *)
end

(** The text over the pose [P] and the promises [R]. *)
module Make (P : POSE_TEXT) (R : PROMISES_TEXT) : sig
  val postconditions :
    (P.t, R.t) Engine_rules.Promises.with_position -> string list
  (** The position's line, if promised, then [R]'s. *)
end
