type ('pose, 'promises) with_position = {
  position : 'pose option;
  promises : 'promises;
}

module With_position (P : sig
  type t

  val to_string : t -> string
end) (R : sig
  type t
  type reads

  val check : t -> reads -> Engine_postcondition.Postcondition.result list
  val to_lines : t -> string list
end) =
struct
  type t = (P.t, R.t) with_position
  type reads = R.reads

  let check (t : t) reads = R.check t.promises reads
  let position (t : t) = t.position

  let to_lines ({ position; promises } : t) =
    Option.fold ~none:[]
      ~some:(fun p -> [ "position " ^ P.to_string p ])
      position
    @ R.to_lines promises
end
