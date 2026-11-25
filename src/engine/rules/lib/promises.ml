type ('pose, 'promises) with_position = {
  position : 'pose option;
  promises : 'promises;
}

module With_position (P : sig
  type t
end) (R : sig
  type t
  type reads

  val check : t -> reads -> Engine_postcondition.Postcondition.result list
end) =
struct
  type t = (P.t, R.t) with_position
  type reads = R.reads

  let check (t : t) reads = R.check t.promises reads
  let position (t : t) = t.position
end
