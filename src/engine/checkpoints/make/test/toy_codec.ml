open Toy_rules
module T = Toy_rules
module F = Json_field

let known ~where allowed obj =
  Engine_plan_codec.Plan_fields.known_fields_only ~where allowed obj

let pose_of_plan ~where obj =
  F.catch (fun () ->
      known ~where [ "place"; "spot" ] obj;
      {
        Pose.place = F.string ~where "place" obj;
        spot = F.string_opt ~where "spot" obj;
      })

let walk ~where args =
  F.catch (fun () ->
      known ~where [ "toward"; "until" ] args;
      Action.Walk
        {
          toward = F.string ~where "toward" args;
          until = F.string ~where "until" args;
        })

let rest ~where args =
  F.catch (fun () ->
      known ~where [] args;
      Action.Rest)

let action_of_plan = function
  | "walk" -> Some walk
  | "rest" -> Some rest
  | _ -> None

let gold ~where obj =
  match F.find "gold" obj with
  | None -> None
  | Some _ -> Some (Engine_postcondition.Count.Gained (F.int ~where "gold" obj))

let postconditions_of_plan ~where obj =
  F.catch (fun () ->
      known ~where [ "gold"; "flags" ] obj;
      {
        Postconditions.gold = gold ~where obj;
        flags =
          Option.fold ~none:[]
            ~some:(F.strings (where ^ "flags"))
            (F.find "flags" obj);
      })
