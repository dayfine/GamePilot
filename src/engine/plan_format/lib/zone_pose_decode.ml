module F = Json_field

type t = Engine_rules.Zone_pose.t

let pose_of_plan ~where obj =
  F.catch (fun () ->
      Plan_fields.known_fields_only ~where [ "place"; "spot" ] obj;
      {
        Engine_rules.Zone_pose.place = F.string ~where "place" obj;
        spot = F.string_opt ~where "spot" obj;
      })
