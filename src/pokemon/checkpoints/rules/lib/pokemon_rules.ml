module Pokemon_action = Pokemon_action
module Postcondition_check = Postcondition_check

module Pose = struct
  include Pose

  type t = declared

  (* A zone is never checked: it holds wherever the player is. *)
  let matches (pose : t) observed =
    match pose with Grid grid -> grid_matches grid observed | Zone _ -> true
end

module Action = struct
  type t = Pokemon_action.t
end

module Postconditions = struct
  include Postconditions

  type reads = Postcondition_check.observed

  let check = Postcondition_check.check
end
