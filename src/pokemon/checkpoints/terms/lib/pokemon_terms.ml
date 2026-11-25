module Own_kind = Own_kind
module Postconditions = Postconditions
module Postcondition_check = Postcondition_check

module Pose = struct
  include Pose

  type t = declared

  (* A zone is never checked: it holds wherever the player is. *)
  let matches (pose : t) observed =
    match pose with Grid grid -> grid_matches grid observed | Zone _ -> true
end

module Kind = struct
  type t = Own_kind.t
end

module Promises = struct
  type t = Postconditions.t
  type reads = Postcondition_check.observed

  let check = Postcondition_check.check
end
