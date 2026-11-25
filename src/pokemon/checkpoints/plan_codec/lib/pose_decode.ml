open Grid_maps
open Engine_plan.Plan_fields
module F = Json_field

let tiles path : Yojson.Safe.t -> Tile_pos.t list = function
  | `List items ->
      List.mapi
        (fun i -> Grid_field.pair (Printf.sprintf "%s[%d]" path i))
        items
  | _ -> F.fail "%s is not an array." path

let grid_pose ~where obj : Pose.grid =
  known_fields_only ~where [ "map"; "tiles"; "facing" ] obj;
  {
    map = F.string ~where "map" obj;
    tiles =
      Option.fold ~none:[] ~some:(tiles (where ^ "tiles")) (F.find "tiles" obj);
    facing = optional ~where "facing" obj Grid_field.direction;
  }

let zone_pose ~where obj : Pose.zone =
  known_fields_only ~where [ "place"; "spot"; "heading" ] obj;
  {
    place = F.string ~where "place" obj;
    spot = F.string_opt ~where "spot" obj;
    heading = optional ~where "heading" obj F.int;
  }

(* [where] ends in a dot: the error names the object. *)
let declared ~where obj : Pose.declared =
  match (F.has "map" obj, F.has "place" obj) with
  | true, false -> Pose.Grid (grid_pose ~where obj)
  | false, true -> Pose.Zone (zone_pose ~where obj)
  | _ ->
      F.fail "%s has a \"map\" or a \"place\", not both or neither."
        (String.sub where 0 (String.length where - 1))
