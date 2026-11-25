open Engine_text
module T = Toy_rules

let pose = Zone_pose_text.pose
let observed = Zone_pose_text.observed

let action : Toy_rules.Action.t -> string = function
  | Story a -> Story_action_text.action a
  | Walk { toward; until } -> Printf.sprintf "walk %s until %s" toward until
  | Inn Rest -> "rest"
  | Inn (Buy item) -> "buy " ^ item

module Promises_text = struct
  type t = Toy_rules.Toy_promises.t

  let postconditions (p : t) =
    Option.fold ~none:[]
      ~some:(fun c -> [ "gold " ^ Engine_postcondition.Count.text c ])
      p.gold
    @ if p.flags = [] then [] else [ "flags " ^ String.concat ", " p.flags ]
end

include With_position_text.Make (Zone_pose_text) (Promises_text)
