module F = Json_field

let known_fields_only ~where allowed (obj : F.obj) =
  match List.find_opt (fun (key, _) -> not (List.mem key allowed)) obj with
  | Some (key, _) -> F.fail "%s%s is not a known field." where key
  | None -> ()

let required ~where key obj = ignore (F.field ~where key obj)

let object_field ~where key obj =
  F.as_object (where ^ key) (F.field ~where key obj)

let optional ~where key obj read =
  Option.map (fun _ -> read ~where key obj) (F.find key obj)
