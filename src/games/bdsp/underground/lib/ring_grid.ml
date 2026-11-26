module D = Grid_geometry.Direction
module P = Grid_geometry.Tile_pos
module G = Grid_maps.Grid
module L = Grid_planning.Leg
module LP = Grid_planning.Leg_planner
module SM = Grid_planning.Step_model

type cell = Wall | Floor | Doorway
type segment = Bottom_east | East_vertical | Top_east
type stop = { tile : P.t; legs : P.t L.t list; wall_dirs : D.t list }

type route = {
  stops : stop list;
  return_door : P.t;
  return_legs : P.t L.t list;
}

let width = 16
let height = 24
let south_door : P.t = { x = 1; y = 21 }
let north_door : P.t = { x = 1; y = 2 }
let min_x = 1
let max_x = 14
let top_y_min = 1
let top_y_max = 3
let bot_y_min = 20
let bot_y_max = 22
let east_x_min = 12
let bot_x0 = 3
let bot_x1 = 6
let bot_x2 = 10
let bot_x3 = 13
let east_y0 = 19
let east_y1 = 14
let east_y2 = 9
let east_y3 = 4
let bucket_bottom_xs = [| bot_x0; bot_x1; bot_x2; bot_x3 |]
let bucket_east_ys = [| east_y0; east_y1; east_y2; east_y3 |]
let bucket_top_xs = [| bot_x3; bot_x2; bot_x1; bot_x0 |]
let bottom_center_y = 21
let east_center_x = 13
let top_center_y = 2

let in_corridor (p : P.t) =
  let in_bottom =
    p.x >= min_x && p.x <= max_x && p.y >= bot_y_min && p.y <= bot_y_max
  in
  let in_top =
    p.x >= min_x && p.x <= max_x && p.y >= top_y_min && p.y <= top_y_max
  in
  let in_east =
    p.x >= east_x_min && p.x <= max_x && p.y >= top_y_min && p.y <= bot_y_max
  in
  in_bottom || in_top || in_east

let cell_at (p : P.t) =
  if P.equal p south_door || P.equal p north_door then Doorway
  else if in_corridor p then Floor
  else Wall

let grid = G.init ~width ~height cell_at

let is_walkable p =
  match G.find grid p with Some (Floor | Doorway) -> true | _ -> false

let is_wall p = match G.find grid p with Some Wall | None -> true | _ -> false
let adjacent_walls p = List.filter (fun dir -> is_wall (P.next p dir)) D.all

let step_model =
  SM.simple ~compare_state:P.compare
    ~press:(fun p dir ->
      let next = P.next p dir in
      if is_walkable next then Some (L.plain_step next dir) else None)
    ~held_at:(fun p dir -> is_wall (P.next p dir))

let plan_legs ~start ~goal =
  LP.plan step_model ~start ~start_facing:None ~at_goal:(P.equal goal)
    ~goal_facing:None

let clamp_bucket b = max 0 (min (Array.length bucket_bottom_xs - 1) b)

let waypoint_of_bucket ~segment ~bucket =
  let i = clamp_bucket bucket in
  match segment with
  | Bottom_east -> { P.x = bucket_bottom_xs.(i); y = bottom_center_y }
  | East_vertical -> { P.x = east_center_x; y = bucket_east_ys.(i) }
  | Top_east -> { P.x = bucket_top_xs.(i); y = top_center_y }

let leg_tile_count (l : _ L.t) =
  match l.kind with L.Walk { tiles; _ } -> tiles | Face | Special_step _ -> 0

let total_tiles legs =
  List.fold_left (fun acc l -> acc + leg_tile_count l) 0 legs

let nearest_doorway start =
  let s_legs = Option.value (plan_legs ~start ~goal:south_door) ~default:[] in
  let n_legs = Option.value (plan_legs ~start ~goal:north_door) ~default:[] in
  if total_tiles n_legs < total_tiles s_legs then (north_door, n_legs)
  else (south_door, s_legs)

let append_stop (pos, acc) tile =
  match plan_legs ~start:pos ~goal:tile with
  | Some legs -> (tile, { tile; legs; wall_dirs = adjacent_walls tile } :: acc)
  | None -> (pos, acc)

let plan_route ~start ~waypoints =
  let cur, rev_stops = List.fold_left append_stop (start, []) waypoints in
  let return_door, return_legs = nearest_doorway cur in
  { stops = List.rev rev_stops; return_door; return_legs }
