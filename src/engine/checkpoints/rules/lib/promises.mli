(** A checkpoint's promises as a product: an end position in the game's pose,
    plus one set of the family's promises ([docs/design/Composable-Rules.md],
    "Postconditions"). The record is the engine's, so the plan codec
    ([Engine_plan_codec.With_position_decode]) and the text
    ([Engine_text.With_position_text]) build the same type without a functor
    path between them. *)

type ('pose, 'promises) with_position = {
  position : 'pose option;
      (** Where the checkpoint promises the player ends: the runner's end check,
          as a plan's declared end is. *)
  promises : 'promises;  (** The family's promises. *)
}

(** The promises [R] with a position in the pose [P]. Its check is [R]'s: the
    position is not a promise the reads check but the runner's end check, as
    today. [P] and [R] have the shapes of [Engine_rules.POSE] and
    [Engine_rules.POSTCONDITIONS]. *)
module With_position (P : sig
  type t
end) (R : sig
  type t
  type reads

  val check : t -> reads -> Engine_postcondition.Postcondition.result list
end) : sig
  type t = (P.t, R.t) with_position
  type reads = R.reads

  val check : t -> reads -> Engine_postcondition.Postcondition.result list
  (** [R]'s check of the promises. *)

  val position : t -> P.t option
  (** The promised end position. *)
end
