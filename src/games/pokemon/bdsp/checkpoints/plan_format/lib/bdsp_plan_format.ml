open Engine_plan_format.Plan_fields
module T = Bdsp_rules
module F = Json_field

let pose_of_plan = Engine_plan_format.Zone_pose_decode.pose_of_plan
let start_of_plan = pose_of_plan

let save_game ~where args =
  F.catch (fun () ->
      known_fields_only ~where [] args;
      T.Action.Save_game)

let underground_farm ~where args =
  F.catch (fun () ->
      known_fields_only ~where [] args;
      T.Action.Underground_farm)

let action_of_plan = function
  | "save_game" -> Some save_game
  | "underground_farm" -> Some underground_farm
  | _ -> None

let postconditions_of_plan ~where obj =
  F.catch (fun () -> known_fields_only ~where [] obj)
