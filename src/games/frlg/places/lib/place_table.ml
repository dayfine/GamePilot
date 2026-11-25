open Grid_maps

type map_object =
  | Npc of string
  | Item of string
  | Hidden_item of string
  | Warp of { warp : string; to_map : string }
  | Not_in_maps of { what : string; tile : Tile_pos.t option }

type place = {
  name : string;
  map : string;
  stand : Tile_pos.t;
  facing : Direction.t;
  map_object : map_object;
}

type t = { places : place list; towns : Towns.t }

let format = "gamepilot-places/1"
let asset = "src/games/frlg/places/places.json"
let ( let* ) = Result.bind

module D = Checkpoints_expand.Table_decode

let error = D.error
let field = D.field
let string = D.string
let fields = D.as_object

let tile where key = function
  | `List [ `Int x; `Int y ] -> Ok { Tile_pos.x; y }
  | _ -> error where "%s is not [x, y]." key

let only = D.only

let not_in_maps where obj what =
  let* tile =
    match List.assoc_opt "tile" obj with
    | None -> Ok None
    | Some v -> Result.map Option.some (tile where "tile" v)
  in
  let* () = only where [ "not_in_maps"; "tile" ] obj in
  Ok (Not_in_maps { what; tile })

let one_key where obj make =
  let* () = only where [ fst (List.hd obj) ] obj in
  Result.map make (string where (fst (List.hd obj)) obj)

let map_object where obj =
  let where = where ^ "object." in
  match obj with
  | ("npc", _) :: _ -> one_key where obj (fun s -> Npc s)
  | ("item", _) :: _ -> one_key where obj (fun s -> Item s)
  | ("hidden_item", _) :: _ -> one_key where obj (fun s -> Hidden_item s)
  | ("warp", _) :: _ ->
      let* () = only where [ "warp"; "to_map" ] obj in
      let* warp = string where "warp" obj in
      let* to_map = string where "to_map" obj in
      Ok (Warp { warp; to_map })
  | ("not_in_maps", _) :: _ ->
      let* what = string where "not_in_maps" obj in
      not_in_maps where obj what
  | _ ->
      error where
        "names none of npc, item, hidden_item, warp, not_in_maps first."

let facing where obj =
  let* name = string where "facing" obj in
  match Direction.of_name name with
  | Some d -> Ok d
  | None -> error where "facing \"%s\" is not a direction." name

let place where (name, value) =
  let* obj = fields (where ^ "places.") name value in
  let where = Printf.sprintf "%splaces.%s." where name in
  let* () = only where [ "map"; "object"; "stand"; "facing" ] obj in
  let* map = string where "map" obj in
  let* stand = Result.bind (field where "stand" obj) (tile where "stand") in
  let* facing = facing where obj in
  let* o = Result.bind (field where "object" obj) (fields where "object") in
  let* map_object = map_object where o in
  Ok { name; map; stand; facing; map_object }

let parse ~source json =
  let where = source ^ ": " in
  let* top = fields where "the table" json in
  let* () = only where [ "format"; "game"; "places"; "towns" ] top in
  let* named = string where "format" top in
  let* () =
    if named = format then Ok ()
    else error where "format is \"%s\", not %s." named format
  in
  let* places =
    Result.bind (field where "places" top) (fields where "places")
  in
  let* places = D.all_ok (List.map (place where) places) in
  let names = List.map (fun p -> p.name) places in
  let* towns =
    match List.assoc_opt "towns" top with
    | None -> Ok Towns.empty
    | Some towns -> Towns.parse ~where ~places:names towns
  in
  Ok { places; towns }

let read () =
  match Frlg_repo_files.Repo_files.locate asset with
  | None -> Error (asset ^ " not found from the working directory")
  | Some path ->
      Result.bind
        (Frlg_repo_files.Json_file.read path)
        (parse ~source:"places.json")

let loaded = lazy (read ())
let load () = Lazy.force loaded
let places t = t.places
let towns t = t.towns

let find t name =
  match List.find_opt (fun p -> p.name = name) t.places with
  | Some p -> Ok p
  | None ->
      Error
        (Name_suggestion.unknown ~what:"place" name
           (List.map (fun p -> p.name) t.places))

let spot p : Checkpoints_expand.Place_routes.spot =
  { map = p.map; tile = p.stand; facing = Some p.facing }

let routes t : Checkpoints_expand.Place_routes.game =
  {
    place = (fun name -> Result.map spot (find t name));
    ride = Lift_stops.ride;
  }

let resolve t : Checkpoints_expand.Fragment_calls.resolve =
 fun ~kind value ~field ->
  match kind with
  | "town" -> Towns.field t.towns value ~field
  | other -> Error ("no parameter kind " ^ other ^ " (town)")
