type tile_color = { min : int * int * int; max : int * int * int }

type t =
  | Home of { cursor : int option; game_tile : int option }
  | Home_dimmed
  | User_select
  | Elsewhere

(* The GBA picture in the frame (daemon/src/viewport.h, nso_gba_viewport). *)
let picture_x = 0.09375
let picture_y = 0.00462963
let picture_w = 0.8125
let picture_h = 0.962963

(* A whole-frame box (the fork's) as a box in the picture, clipped to it. *)
let in_picture ({ x; y; w; h } : Wire.box) : Wire.box =
  let x0 = Float.max x picture_x and y0 = Float.max y picture_y in
  let x1 = Float.min (x +. w) (picture_x +. picture_w)
  and y1 = Float.min (y +. h) (picture_y +. picture_h) in
  {
    x = (x0 -. picture_x) /. picture_w;
    y = (y0 -. picture_y) /. picture_h;
    w = (x1 -. x0) /. picture_w;
    h = (y1 -. y0) /. picture_h;
  }

let stats_boxes =
  [
    (* HomeMenuDetector *)
    ( "home.top",
      in_picture { x = 0.510223; y = 0.019835; w = 0.441450; h = 0.034711 } );
    ("home.iconrow_right", in_picture { x = 0.85; y = 0.70; w = 0.13; h = 0.15 });
    ("home.iconrow_icons", in_picture { x = 0.20; y = 0.70; w = 0.60; h = 0.15 });
    ("home.bottom_row", in_picture { x = 0.10; y = 0.92; w = 0.10; h = 0.05 });
    ("home.bottom_icons", in_picture { x = 0.70; y = 0.92; w = 0.28; h = 0.05 });
    ("home.game_slot", in_picture { x = 0.08; y = 0.25; w = 0.10; h = 0.38 });
    ( "home.close_game_top",
      in_picture { x = 0.226358; y = 0.272648; w = 0.407445; h = 0.033989 } );
    (* StartGameUserSelectDetector_Switch1 *)
    ("user.top_row", in_picture { x = 0.50; y = 0.47; w = 0.45; h = 0.05 });
    ("user.mid_row", in_picture { x = 0.10; y = 0.55; w = 0.80; h = 0.02 });
    ("user.user_slot", in_picture { x = 0.45; y = 0.55; w = 0.10; h = 0.35 });
  ]

let picture_id = "home.picture"
let tiles = 4

(* Tile k's left edge and the tiles' pitch, in the frame; the cursor's frame
   runs along the tile's top, its art fills the middle. *)
let tile_left = 0.098
let tile_pitch = 0.2125
let tile_inner_w = 0.17
let cursor_y = 0.252
let cursor_h = 0.014
let art_y = 0.30
let art_h = 0.30
let cursor_id k = Printf.sprintf "home.cursor%d" k
let art_id k = Printf.sprintf "home.tile%d" k

(* The cursor frame's cyan. *)
let cursor_min_green = 150
let cursor_min_blue = 200
let cursor_max_red = 120
let channel_max = 255
let cursor_min = (0, cursor_min_green, cursor_min_blue)
let cursor_max = (cursor_max_red, channel_max, channel_max)
let tile_x k = tile_left +. (tile_pitch *. float_of_int k)

let tile_probes (color : tile_color) k =
  [
    Wire.color_count_probe ~id:(cursor_id k)
      ~box:
        (in_picture
           { x = tile_x k; y = cursor_y; w = tile_inner_w; h = cursor_h })
      ~delivery:Every ~min:cursor_min ~max:cursor_max;
    Wire.color_count_probe ~id:(art_id k)
      ~box:(in_picture { x = tile_x k; y = art_y; w = tile_inner_w; h = art_h })
      ~delivery:Every ~min:color.min ~max:color.max;
  ]

let probes color =
  Wire.color_stats_probe ~id:picture_id
    ~box:{ x = 0.; y = 0.; w = 1.; h = 1. }
    ~delivery:Every
  :: List.map
       (fun (id, box) -> Wire.color_stats_probe ~id ~box ~delivery:Every)
       stats_boxes
  @ List.concat_map (tile_probes color) (List.init tiles Fun.id)

type stats = { mean : Wire.rgb; stddev : Wire.rgb }

let stats m id =
  match Effects.probe m id with
  | Some (Wire.Color_stats { mean; stddev }) -> Some { mean; stddev }
  | Some (Wire.Template_match _ | Wire.Color_count _ | Wire.Other _) | None ->
      None

let fraction m id =
  match Effects.probe m id with
  | Some (Wire.Color_count { fraction; _ }) -> fraction
  | Some (Wire.Color_stats _ | Wire.Template_match _ | Wire.Other _) | None ->
      0.

let sum (c : Wire.rgb) = c.r +. c.g +. c.b

let distance (a : Wire.rgb) (b : Wire.rgb) =
  let d x y = (x -. y) *. (x -. y) in
  Float.sqrt (d a.r b.r +. d a.g b.g +. d a.b b.b)

(* SolidColorTest's is_white and is_grey with their default stddev limit. *)
let solid_max_stddev = 10.
let white_max_distance = 0.08
let grey_max_distance = 0.1
let hue_min_sum = 100.
let white_min_sum = 500.
let channels = 3.

let share_distance (c : Wire.rgb) =
  let total = sum c in
  if total <= 0. then Float.infinity
  else
    let third = 1. /. channels in
    let d x = (x /. total) -. third in
    Float.sqrt ((d c.r *. d c.r) +. (d c.g *. d c.g) +. (d c.b *. d c.b))

let is_white s =
  sum s.mean >= white_min_sum
  && sum s.stddev <= solid_max_stddev
  && share_distance s.mean <= white_max_distance

let is_grey ~min_sum ~max_sum s =
  let total = sum s.mean in
  total >= min_sum && total <= max_sum
  && sum s.stddev <= solid_max_stddev
  && (total < hue_min_sum || share_distance s.mean <= grey_max_distance)

let dark_max_sum = 200.
let max_flat_stddev = 20.
let min_icons_stddev = 10.
let min_detail_stddev = 50.
let max_same_color = 20.

(* HomeMenuDetector::detect_only, its boxes clipped and the user icon left
   out. *)
let home_theme g =
  let row = g "home.bottom_row" in
  let total = sum row.mean in
  if total < dark_max_sum then Some false
  else if total > white_min_sum then Some true
  else None

(* The detail limits scale with the picture's brightness: [scale] 1 lit. *)
let home_detail ~scale g =
  let at_least id limit = sum (g id).stddev >= limit *. scale in
  at_least "home.close_game_top" min_detail_stddev
  && sum (g "home.top").stddev <= max_flat_stddev *. scale
  && at_least "home.bottom_icons" min_icons_stddev
  && at_least "home.iconrow_icons" min_detail_stddev
  && at_least "home.game_slot" min_detail_stddev

let home_flat g white =
  let row = g "home.bottom_row" and right = g "home.iconrow_right" in
  let solid s =
    if white then is_white s else is_grey ~min_sum:0. ~max_sum:dark_max_sum s
  in
  solid row && solid right
  && distance row.mean right.mean <= max_same_color
  && distance (g "home.top").mean row.mean <= max_same_color

let is_home g =
  match home_theme g with
  | None -> false
  | Some white -> home_detail ~scale:1. g && home_flat g white

(* Dimmed, the dark theme's grey (51 a channel lit) reads 8 on console B: a
   flat band between black and the lit grey, the detail limits scaled by it.
   A black picture (a launch) is below the band. *)
let dark_lit_sum = 153.
let dimmed_min_sum = 15.
let dimmed_max_sum = 100.

let is_home_dimmed g =
  let total = sum (g "home.bottom_row").mean in
  total >= dimmed_min_sum && total < dimmed_max_sum && home_flat g false
  && home_detail ~scale:(total /. dark_lit_sum) g

(* StartGameUserSelectDetector_Switch1::detect. *)
let user_grey_min = 50.
let user_grey_max = 300.

let is_user_select g =
  let row = g "user.top_row" and mid = g "user.mid_row" in
  let bottom = g "home.bottom_row" in
  let grey = is_grey ~min_sum:user_grey_min ~max_sum:user_grey_max in
  let white = (not (grey bottom)) && sum bottom.mean > white_min_sum in
  let solid s = if white then is_white s else grey s in
  sum bottom.stddev <= solid_max_stddev
  && (grey bottom || white)
  && sum (g "home.bottom_icons").stddev >= min_detail_stddev
  && sum row.stddev <= solid_max_stddev
  && sum mid.stddev <= solid_max_stddev
  && solid row && solid mid
  && distance bottom.mean row.mean <= max_same_color
  && sum (g "user.user_slot").stddev >= min_detail_stddev

(* The cursor's cyan covers 0.36 to 0.40 of the strip above its tile, none
   above the others; the FireRed tile's orange 0.41, the others' 0.05 at
   most. *)
let min_cursor_fraction = 0.15
let min_art_fraction = 0.2
let first_tile pred = List.find_opt pred (List.init tiles Fun.id)

let home m =
  Home
    {
      cursor =
        first_tile (fun k -> fraction m (cursor_id k) >= min_cursor_fraction);
      game_tile =
        first_tile (fun k -> fraction m (art_id k) >= min_art_fraction);
    }

let classify m g =
  if is_home g then home m
  else if is_home_dimmed g then Home_dimmed
  else if is_user_select g then User_select
  else Elsewhere

let read m =
  let all = List.map (fun (id, _) -> (id, stats m id)) stats_boxes in
  if List.exists (fun (_, s) -> Option.is_none s) all then Elsewhere
  else classify m (fun id -> Option.get (List.assoc id all))

let black_max_sum = 30.

let black m =
  match stats m picture_id with
  | Some s -> sum s.mean < black_max_sum
  | None -> false

let tile = function None -> "none" | Some k -> string_of_int k

let to_string = function
  | Home { cursor; game_tile } ->
      Printf.sprintf "HOME (cursor on tile %s, the game's tile %s)"
        (tile cursor) (tile game_tile)
  | Home_dimmed -> "HOME, dimmed (tiles not read)"
  | User_select -> "the user select"
  | Elsewhere -> "not HOME"
