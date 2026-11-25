(* A place's object found on its map as Grid_maps decodes it, and whether the
   place's stand tile can use it. *)

open Grid_maps
open Frlg_places

let ( let* ) = Result.bind

(* The tile of the one object of [kind] with that script. *)
let scripted (map : Map_data.t) kind script =
  match
    List.filter
      (fun (o : Map_features.map_object) ->
        o.kind = kind && o.script = Some script)
      map.objects
  with
  | [ o ] -> Ok (Some o.object_pos)
  | [] -> Error ("no object with script " ^ script)
  | many ->
      Error
        (Printf.sprintf "%d objects have script %s" (List.length many) script)

let hidden (map : Map_data.t) flag =
  match
    List.find_opt
      (fun (h : Map_features.hidden_item) -> h.hidden_flag = flag)
      map.hidden_items
  with
  | Some h -> Ok (Some h.hidden_pos)
  | None -> Error ("no hidden item with flag " ^ flag)

(* "warp_<n>": the map's nth warp, as pret numbers them. *)
let warp (map : Map_data.t) name to_map =
  let index = Scanf.sscanf_opt name "warp_%d%!" Fun.id in
  match Option.bind index (List.nth_opt map.warps) with
  | None -> Error ("no warp " ^ name)
  | Some { warp_pos; destination = Some d; _ } when d.to_map = to_map ->
      Ok (Some warp_pos)
  | Some _ -> Error (name ^ " does not lead to " ^ to_map)

let tile map (o : Place_table.map_object) =
  match o with
  | Npc script -> scripted map Map_features.Npc script
  | Item script -> scripted map Map_features.Item script
  | Hidden_item flag -> hidden map flag
  | Warp { warp = name; to_map } -> warp map name to_map
  | Not_in_maps { tile; _ } -> Ok tile

(* Across a counter, the object is two tiles ahead. *)
let counter_reach = 2

let ahead (p : Place_table.place) target =
  let rec steps tile n =
    if n = 0 then tile else steps (Tile_pos.next tile p.facing) (n - 1)
  in
  List.exists
    (fun n -> Tile_pos.equal (steps p.stand n) target)
    (List.init counter_reach succ)

let next_to (p : Place_table.place) door =
  List.exists
    (fun d -> Tile_pos.equal (Tile_pos.next p.stand d) door)
    Direction.all

let usable (p : Place_table.place) object_tile =
  let ok =
    match p.map_object with
    | Warp _ -> next_to p object_tile
    | _ -> ahead p object_tile
  in
  if ok then Ok ()
  else
    Error
      (Printf.sprintf "%s cannot use %s from %s facing %s" p.name
         (Tile_pos.to_string object_tile)
         (Tile_pos.to_string p.stand)
         (Direction.name p.facing))

let check map (p : Place_table.place) =
  let* found = tile map p.map_object in
  Option.fold ~none:(Ok ()) ~some:(usable p) found
