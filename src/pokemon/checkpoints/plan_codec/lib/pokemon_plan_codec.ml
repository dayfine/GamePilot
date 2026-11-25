module T = Pokemon_terms
module F = Json_field

let pose_of_plan ~where obj =
  F.catch (fun () -> Pose_decode.declared ~where obj)

let kind_of_plan name =
  Option.map
    (fun read ~where args -> F.catch (fun () -> read ~where args))
    (Kind_decode.decoder name)

let postconditions_of_plan ~where obj =
  F.catch (fun () -> Postcondition_decode.postconditions ~where obj)
