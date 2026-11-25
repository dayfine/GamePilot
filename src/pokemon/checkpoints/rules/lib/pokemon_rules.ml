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

  let to_string = Pokemon_action.to_string
end

module Postconditions = struct
  include Postconditions

  type reads = Postcondition_check.observed

  let check = Postcondition_check.check
end

(* A route's or ready's target, as the declared end reads it today. *)
let ends_at : Action.t -> Pose.t option = function
  | Route { target; _ } | Ready target -> Some (Grid target)
  | New_game | Options | Legs _ | Step _ | Battle _ | Train _ | Heal | Shop _ ->
      None

let position (p : Postconditions.t) =
  Option.map (fun grid -> Pose.Grid grid) p.position
