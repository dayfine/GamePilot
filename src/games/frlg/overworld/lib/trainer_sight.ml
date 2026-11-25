open Grid_maps
open Grid_geometry

type trainer = { map : int; at : Tile_pos.t }

let notice_ms = 1500
let speaks_ms = 1000

let full_watch_ms ~approach_tiles =
  notice_ms
  + (Move_mechanics.frlg.walk.tile.across_ms * approach_tiles)
  + speaks_ms

let is_wall (map : Map_data.t) pos =
  match Grid.find map.tiles pos with
  | Some (Tile_kind.Wall | Outside) | None -> true
  | Some _ -> false

(* The fork's sees_from(): from [from], [sight] tiles each way [looks], up to
   a wall. *)
let sees_from (map : Map_data.t) (trainer : Map_features.trainer) from pos =
  let rec along tile look n =
    n > 0
    &&
    let seen = Tile_pos.next tile look in
    (not (is_wall map seen))
    && (Tile_pos.equal seen pos || along seen look (n - 1))
  in
  List.exists (fun look -> along from look trainer.sight) trainer.looks

let span lo hi = List.init (hi - lo + 1) (fun i -> lo + i)

let box_tiles ({ top_left; bottom_right } : Map_features.tile_box) =
  List.concat_map
    (fun y ->
      List.map (fun x -> { Tile_pos.x; y }) (span top_left.x bottom_right.x))
    (span top_left.y bottom_right.y)

(* The tiles the object may stand on: its wander box, or its own tile. *)
let standing (o : Map_features.map_object) =
  match o.wander with None -> [ o.object_pos ] | Some box -> box_tiles box

let may_see map (o : Map_features.map_object) pos =
  match o.trainer with
  | None -> false
  | Some trainer ->
      List.exists (fun from -> sees_from map trainer from pos) (standing o)

let seeing (w : Frlg_steps.world) ~beaten (place : Connected_maps.place) =
  let map = Connected_maps.map w.maps place.map in
  List.filter_map
    (fun (o : Map_features.map_object) ->
      let trainer = { map = place.map; at = o.object_pos } in
      if
        (not (w.hidden o))
        && (not (List.mem trainer beaten))
        && may_see map o place.tile
      then Some (trainer, o)
      else None)
    map.objects
  |> List.map fst

let sight_of (w : Frlg_steps.world) (trainer : trainer) =
  let map = Connected_maps.map w.maps trainer.map in
  List.fold_left
    (fun best (o : Map_features.map_object) ->
      match o.trainer with
      | Some { sight; _ } when Tile_pos.equal o.object_pos trainer.at ->
          max best sight
      | _ -> best)
    0 map.objects

let sight_onto w ~beaten place =
  List.fold_left
    (fun best trainer -> max best (sight_of w trainer))
    0 (seeing w ~beaten place)

(* The way from [a] to [b] on its row or column. *)
let towards (a : Tile_pos.t) (b : Tile_pos.t) =
  if a.x = b.x then if b.y < a.y then Direction.North else South
  else if b.x < a.x then West
  else East

(* The tiles beside [player] toward each tile [o] may see them from. *)
let stops_beside map (o : Map_features.map_object) sight
    (player : Connected_maps.place) =
  standing o
  |> List.filter (fun from -> sees_from map sight from player.tile)
  |> List.map (fun from ->
         {
           player with
           tile = Tile_pos.next player.tile (towards player.tile from);
         })

let walked_up (w : Frlg_steps.world) (trainer : trainer) player =
  let map = Connected_maps.map w.maps trainer.map in
  List.concat_map
    (fun (o : Map_features.map_object) ->
      match o.trainer with
      | Some sight when Tile_pos.equal o.object_pos trainer.at ->
          stops_beside map o sight player
      | _ -> [])
    map.objects
  |> List.sort_uniq Connected_maps.compare_place
