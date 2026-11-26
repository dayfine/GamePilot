open Engine_plan_format.Plan_fields
module T = Plza_rules
module F = Json_field

let pose_of_plan ~where obj =
  F.catch (fun () ->
      known_fields_only ~where [ "place"; "spot" ] obj;
      {
        T.Pose.place = F.string ~where "place" obj;
        spot = F.string_opt ~where "spot" obj;
      })

let start_of_plan = pose_of_plan

let walk ~where args =
  F.catch (fun () -> T.Action.Walk (Walk_decode.walk ~where args))

let action_of_plan = function "walk" -> Some walk | _ -> None

let other_field key =
  Printf.sprintf
    "has \"%s\": its fields are talk_prompt, wild_zone and near_rocks (true or \
     false), party (a count) and minimap (a recorded name)"
    key

(* One field of a signature. *)
let field (s : T.Screen_signature.t) = function
  | "talk_prompt", `Bool b -> Ok { s with talk_prompt = Some b }
  | "wild_zone", `Bool b -> Ok { s with wild_zone = Some b }
  | "near_rocks", `Bool b -> Ok { s with near_rocks = Some b }
  | "party", `Int n -> Ok { s with party = Some n }
  | "minimap", `String name -> Ok { s with minimap = Some name }
  | key, _ -> Error (other_field key)

let of_fields fields =
  List.fold_left
    (fun s kv -> Result.bind s (fun s -> field s kv))
    (Ok T.Screen_signature.nothing) fields

let signature_of_plan = function
  | `Assoc fields -> (
      match of_fields fields with
      | Ok s when s = T.Screen_signature.nothing -> Error "names nothing"
      | result -> result)
  | _ -> Error "is not an object"

let place ~where = function
  | None -> None
  | Some value -> (
      match signature_of_plan value with
      | Ok s -> Some s
      | Error detail -> F.fail "%splace %s." where detail)

(* A story flag PLZA reads at a checkpoint's end. *)
let readable ~where flag =
  if List.mem flag T.readable_flags then flag
  else
    F.fail "%sflags has \"%s\": PLZA reads only %s." where flag
      (String.concat ", " T.readable_flags)

let flags ~where = function
  | None -> []
  | Some value -> List.map (readable ~where) (F.strings (where ^ "flags") value)

let postconditions_of_plan ~where obj =
  F.catch (fun () ->
      known_fields_only ~where [ "place"; "flags" ] obj;
      {
        T.Postconditions.place = place ~where (F.find "place" obj);
        flags = flags ~where (F.find "flags" obj);
      })
