open Grid_maps
module F = Json_field

(* Every reader takes [where], the prefix of the object's fields
   ("f: checkpoint."), as Json_field does. *)

let known_fields_only ~where allowed (obj : F.obj) =
  match List.find_opt (fun (key, _) -> not (List.mem key allowed)) obj with
  | Some (key, _) -> F.fail "%s%s is not a known field." where key
  | None -> ()

let required ~where key obj = ignore (F.field ~where key obj)

let object_field ~where key obj =
  F.as_object (where ^ key) (F.field ~where key obj)

let optional ~where key obj read =
  Option.map (fun _ -> read ~where key obj) (F.find key obj)

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

let item ~where obj : Plan.item =
  known_fields_only ~where [ "item"; "quantity" ] obj;
  { item = F.string ~where "item" obj; quantity = F.int ~where "quantity" obj }
