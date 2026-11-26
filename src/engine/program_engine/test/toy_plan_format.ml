open Engine_plan_format
module F = Json_field

let known ~where allowed obj = Plan_fields.known_fields_only ~where allowed obj

module Walk_decode = struct
  type t = Toy_rules.Toy_walk.t

  let names = [ "walk" ]

  let walk ~where args =
    F.catch (fun () ->
        known ~where [ "toward"; "until" ] args;
        {
          Toy_rules.Toy_walk.toward = F.string ~where "toward" args;
          until = F.string ~where "until" args;
        })

  let of_plan = function "walk" -> Some walk | _ -> None
end

module Inn_decode = struct
  type t = Toy_rules.Toy_inn.t

  let names = [ "rest"; "buy" ]

  let rest ~where args =
    F.catch (fun () ->
        known ~where [] args;
        Toy_rules.Toy_inn.Rest)

  let buy ~where args =
    F.catch (fun () ->
        known ~where [ "item" ] args;
        Toy_rules.Toy_inn.Buy (F.string ~where "item" args))

  let of_plan = function "rest" -> Some rest | "buy" -> Some buy | _ -> None
end

module Promises_decode = struct
  type t = Toy_rules.Toy_promises.t

  let keys = [ "gold"; "flags" ]

  let gold ~where obj =
    match F.find "gold" obj with
    | None -> None
    | Some _ ->
        Some (Engine_postcondition.Count.Gained (F.int ~where "gold" obj))

  let promises_of_plan ~where obj =
    F.catch (fun () ->
        {
          Toy_rules.Toy_promises.gold = gold ~where obj;
          flags =
            Option.fold ~none:[]
              ~some:(F.strings (where ^ "flags"))
              (F.find "flags" obj);
        })
end

module T = Toy_rules

let parts =
  Action_parts.
    [
      Part ((module Story_action_decode), fun a -> Toy_rules.Action.Story a);
      Part ((module Walk_decode), fun w -> Toy_rules.Action.Walk w);
      Part ((module Inn_decode), fun i -> Toy_rules.Action.Inn i);
    ]

let pose_of_plan = Zone_pose_decode.pose_of_plan
let start_of_plan = Zone_pose_decode.pose_of_plan
let action_of_plan = Action_parts.action_of_plan parts

include With_position_decode.Make (Zone_pose_decode) (Promises_decode)
