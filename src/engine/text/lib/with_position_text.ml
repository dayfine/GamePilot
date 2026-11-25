module type POSE_TEXT = sig
  type t

  val pose : t -> string
end

module type PROMISES_TEXT = sig
  type t

  val postconditions : t -> string list
end

module Make (P : POSE_TEXT) (R : PROMISES_TEXT) = struct
  let postconditions
      ({ position; promises } : (P.t, R.t) Engine_rules.Promises.with_position)
      =
    Option.fold ~none:[] ~some:(fun p -> [ "position " ^ P.pose p ]) position
    @ R.postconditions promises
end
