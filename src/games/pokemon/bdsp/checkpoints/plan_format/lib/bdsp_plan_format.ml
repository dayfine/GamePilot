open Engine_plan_format.Plan_fields
module T = Bdsp_rules
module F = Json_field

let pose_of_plan = Engine_plan_format.Zone_pose_decode.pose_of_plan
let start_of_plan = pose_of_plan

let no_args_action action ~where args =
  F.catch (fun () ->
      known_fields_only ~where [] args;
      action)

let action_of_plan = function
  | "save_game" -> Some (no_args_action T.Action.Save_game)
  | "static_rng" -> Some (no_args_action T.Action.Static_rng)
  | _ -> None

let postconditions_of_plan ~where obj =
  F.catch (fun () -> known_fields_only ~where [] obj)
