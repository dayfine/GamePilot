module T = Pokemon_rules
module F = Json_field

let pose_of_plan ~where obj =
  F.catch (fun () -> Pose_decode.declared ~where obj)

let start_of_plan ~where obj = F.catch (fun () -> Pose_decode.start ~where obj)

let action_of_plan name =
  Option.map
    (fun read ~where args -> F.catch (fun () -> read ~where args))
    (Pokemon_action_decode.decoder name)

let postconditions_of_plan ~where obj =
  F.catch (fun () -> Postcondition_decode.postconditions ~where obj)
