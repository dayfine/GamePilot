open Engine_plan_codec.Plan_fields
module T = Plza_rules
module F = Json_field

let pose_of_plan ~where obj =
  F.catch (fun () ->
      known_fields_only ~where [ "place"; "spot" ] obj;
      {
        T.Pose.place = F.string ~where "place" obj;
        spot = F.string_opt ~where "spot" obj;
      })

let walk ~where args =
  F.catch (fun () -> T.Action.Walk (Walk_decode.walk ~where args))

let kind_of_plan = function "walk" -> Some walk | _ -> None

let postconditions_of_plan ~where obj =
  F.catch (fun () -> known_fields_only ~where [] obj)
