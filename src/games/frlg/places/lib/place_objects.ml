open Grid_maps

let maps_dir = "third_party/PokemonSimulation/data/games/frlg/maps/runtime"
let ( let* ) = Result.bind

let load_map name =
  let path = Filename.concat maps_dir (name ^ ".json") in
  match Frlg_repo_files.Repo_files.locate path with
  | None -> Error (path ^ " not found from the working directory")
  | Some file -> Frlg_repo_files.Json_file.read file

let list key = function
  | `Assoc fields -> (
      match List.assoc_opt key fields with Some (`List l) -> l | _ -> [])
  | _ -> []

let str key = function
  | `Assoc fields -> (
      match List.assoc_opt key fields with
      | Some (`String s) -> Some s
      | _ -> None)
  | _ -> None

let coord = function
  | `Assoc fields -> (
      match List.assoc_opt "coord" fields with
      | Some (`List [ `Int x; `Int y ]) -> Some { Tile_pos.x; y }
      | _ -> None)
  | _ -> None

(* The coord of the one entry of [key] whose [field] is [id]. *)
let unique json ~key ~field id =
  match List.filter (fun o -> str field o = Some id) (list key json) with
  | [ o ] -> Ok (coord o)
  | [] -> Error (Printf.sprintf "no %s with %s %s" key field id)
  | many ->
      Error (Printf.sprintf "%d %s have %s %s" (List.length many) key field id)

let warp_tile json ~warp ~to_map =
  let index =
    if String.starts_with ~prefix:"warp_" warp then
      int_of_string_opt (String.sub warp 5 (String.length warp - 5))
    else None
  in
  match Option.bind index (List.nth_opt (list "warps" json)) with
  | None -> Error ("no warp " ^ warp)
  | Some w when str "to_map" w = Some to_map -> Ok (coord w)
  | Some w ->
      Error
        (Printf.sprintf "%s leads to %s, not %s" warp
           (Option.value ~default:"no map" (str "to_map" w))
           to_map)

let tile json (o : Place_table.map_object) =
  match o with
  | Npc id -> unique json ~key:"npcs" ~field:"source_script" id
  | Item id -> unique json ~key:"items" ~field:"source_script" id
  | Hidden_item flag -> unique json ~key:"hidden_items" ~field:"flag" flag
  | Warp { warp; to_map } -> warp_tile json ~warp ~to_map
  | Not_in_maps { tile; _ } -> Ok tile

let counter_reach = 2

let rec steps tile facing n =
  if n = 0 then tile else steps (Tile_pos.next tile facing) facing (n - 1)

(* The object is straight ahead of the stand tile, within reach. *)
let ahead (p : Place_table.place) target =
  List.init counter_reach (fun i -> steps p.stand p.facing (i + 1))
  |> List.exists (Tile_pos.equal target)

let next_to (p : Place_table.place) door =
  List.exists
    (fun d -> Tile_pos.equal (Tile_pos.next p.stand d) door)
    Direction.all

let usable (p : Place_table.place) tile =
  match p.map_object with
  | Warp _ when next_to p tile -> Ok ()
  | Warp _ ->
      Error
        ("the door " ^ Tile_pos.to_string tile
       ^ " is not next to the stand tile")
  | _ when ahead p tile -> Ok ()
  | _ ->
      Error
        (Printf.sprintf "the object %s is not ahead of %s facing %s"
           (Tile_pos.to_string tile)
           (Tile_pos.to_string p.stand)
           (Direction.name p.facing))

let check json (p : Place_table.place) =
  let* found = tile json p.map_object in
  Option.fold ~none:(Ok ()) ~some:(usable p) found
