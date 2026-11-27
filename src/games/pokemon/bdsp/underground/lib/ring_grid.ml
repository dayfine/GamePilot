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

type bounds = {
  min_x : int;
  max_x : int;
  top_y_min : int;
  top_y_max : int;
  bot_y_min : int;
  bot_y_max : int;
  east_x_min : int;
}

type centers = { bottom_y : int; east_x : int; top_y : int }

let width = 16
let height = 24
let south_door : P.t = { x = 1; y = 20 }
let north_door : P.t = { x = 1; y = 1 }

let bounds =
  {
    min_x = 1;
    max_x = 14;
    top_y_min = 1;
    top_y_max = 3;
    bot_y_min = 20;
    bot_y_max = 22;
    east_x_min = 12;
  }

type bucket_coords = {
  b0 : int;
  b1 : int;
  b2 : int;
  b3 : int;
  b4 : int;
  b5 : int;
  b6 : int;
  b7 : int;
}

let coords_array c = [| c.b0; c.b1; c.b2; c.b3; c.b4; c.b5; c.b6; c.b7 |]
let centers = { bottom_y = 20; east_x = 14; top_y = 1 }

let bucket_bottom_xs =
  coords_array
    { b0 = 2; b1 = 3; b2 = 5; b3 = 7; b4 = 8; b5 = 10; b6 = 12; b7 = 14 }

let bucket_east_ys =
  coords_array
    { b0 = 19; b1 = 16; b2 = 14; b3 = 12; b4 = 9; b5 = 7; b6 = 5; b7 = 2 }

let bucket_top_xs = Array.of_list (List.rev (Array.to_list bucket_bottom_xs))

let in_corridor (p : P.t) =
  let in_bottom =
    p.x >= bounds.min_x && p.x <= bounds.max_x && p.y >= bounds.bot_y_min
    && p.y <= bounds.bot_y_max
  in
  let in_top =
    p.x >= bounds.min_x && p.x <= bounds.max_x && p.y >= bounds.top_y_min
    && p.y <= bounds.top_y_max
  in
  let in_east =
    p.x >= bounds.east_x_min && p.x <= bounds.max_x && p.y >= bounds.top_y_min
    && p.y <= bounds.bot_y_max
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
  | Bottom_east -> { P.x = bucket_bottom_xs.(i); y = centers.bottom_y }
  | East_vertical -> { P.x = centers.east_x; y = bucket_east_ys.(i) }
  | Top_east -> { P.x = bucket_top_xs.(i); y = centers.top_y }

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
