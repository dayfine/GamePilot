module Pose = Engine_rules.Zone_pose

module Action = struct
  type t = Save_game | Static_rng

  let to_string = function
    | Save_game -> "save_game"
    | Static_rng -> "static_rng"
end

module Postconditions = struct
  type t = unit
  type reads = unit

  let check () () = []
  let to_lines () = []
end

let ends_at _ = None
let position () = None
let end_place () = None
