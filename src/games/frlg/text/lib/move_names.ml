type t = (string * string) list

let first_name (slug, names) =
  match names with `List (`String n :: _) -> Some (slug, n) | _ -> None

let of_json ~language json =
  match Yojson.Safe.Util.member language json with
  | `Assoc slugs -> List.filter_map first_name slugs
  | _ -> failwith ("no move names for " ^ language)

let load ~language path = of_json ~language (Yojson.Safe.from_file path)
let name t slug = List.assoc_opt slug t
