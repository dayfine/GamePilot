open Bdsp_underground
module PB = Switch_home.Picture_box
module BF = Wire.Blob_find

type offset = { dx : int; dy : int; dx_norm : float; dy_norm : float }

type star_config = {
  min_r : int;
  min_g : int;
  min_b : int;
  max_ch : int;
  min_area : float;
  max_area : float;
  static_match_px : float;
}

type playfield_geometry = {
  game_w : float;
  game_h : float;
  player_x : float;
  player_y : float;
  exclude_dx : float;
  exclude_dy : float;
  deadzone_x : float;
  deadzone_y : float;
}

(* Two playfield boxes excluding the top-left minimap (x < 0.24, y < 0.36). *)
let right_box : Wire.box = { x = 0.24; y = 0.04; w = 0.72; h = 0.86 }
let left_box : Wire.box = { x = 0.08; y = 0.36; w = 0.16; h = 0.54 }
let right_probe_id = "bdsp_wall_star_right"
let left_probe_id = "bdsp_wall_star_left"

(* Measured from Console A captures run-2/000231.jpg, prev-run-2/000268.jpg,
   and run-1/000128.jpg: sparkle stars have bright white-gold cores in RGB
   (245..255, 240..255, 230..255) with area 50..2500 px on 1920x1080, while
   expanding cyan radar rings exceed 2500 px and red-orange wall torches have
   blue < 140 (or stay static across pre/post radar frames). *)
let star =
  {
    min_r = 245;
    min_g = 240;
    min_b = 230;
    max_ch = 255;
    min_area = 50.;
    max_area = 2500.;
    static_match_px = 35.;
  }

let field =
  {
    game_w = 1920.;
    game_h = 1080.;
    player_x = 0.50;
    player_y = 0.48;
    exclude_dx = 0.035;
    exclude_dy = 0.055;
    deadzone_x = 0.035;
    deadzone_y = 0.045;
  }

let star_filter : BF.filter =
  {
    low = (star.min_r, star.min_g, star.min_b);
    high = (star.max_ch, star.max_ch, star.max_ch);
  }

let find_params =
  match
    BF.params ~filters:[ star_filter ] ~min_area:star.min_area
      ~max_area:star.max_area ()
  with
  | Ok p -> p
  | Error _ ->
      {
        BF.filters = [ star_filter ];
        min_area = star.min_area;
        max_area = Some star.max_area;
        min_size = None;
        max_size = None;
        margin = None;
        shape = None;
        masked = false;
      }

let make_probe ~picture id box =
  Option.map
    (fun b -> Wire.find_probe ~id ~box:b ~delivery:Every find_params)
    (PB.clipped ~picture box)

let probes ~picture =
  List.filter_map Fun.id
    [
      make_probe ~picture right_probe_id right_box;
      make_probe ~picture left_probe_id left_box;
    ]

let blobs_of m id =
  match Effects.probe m id with Some (Wire.Find { blobs }) -> blobs | _ -> []

let all_blobs m = blobs_of m right_probe_id @ blobs_of m left_probe_id
let blob_center (b : BF.blob) = (b.x +. (b.w /. 2.), b.y +. (b.h /. 2.))
let blob_area (b : BF.blob) = b.w *. b.h *. b.fill

let on_player_sprite (b : BF.blob) =
  let cx, cy = blob_center b in
  let nx = cx /. field.game_w and ny = cy /. field.game_h in
  Float.abs (nx -. field.player_x) < field.exclude_dx
  && Float.abs (ny -. field.player_y) < field.exclude_dy

let near_any_before before (b : BF.blob) =
  let cx, cy = blob_center b in
  List.exists
    (fun prev ->
      let px, py = blob_center prev in
      Float.abs (cx -. px) <= star.static_match_px
      && Float.abs (cy -. py) <= star.static_match_px)
    before

let sign_with_deadzone dz v = if v < -.dz then -1 else if v > dz then 1 else 0

let offset_of_blob (b : BF.blob) =
  let cx, cy = blob_center b in
  let dx_norm = (cx /. field.game_w) -. field.player_x in
  let dy_norm = (cy /. field.game_h) -. field.player_y in
  {
    dx = sign_with_deadzone field.deadzone_x dx_norm;
    dy = sign_with_deadzone field.deadzone_y dy_norm;
    dx_norm;
    dy_norm;
  }

let pick_largest blobs =
  let step acc b =
    let a = blob_area b in
    match acc with
    | None -> Some (b, a)
    | Some (_, best_a) when a > best_a -> Some (b, a)
    | _ -> acc
  in
  Option.map (fun (b, _) -> offset_of_blob b) (List.fold_left step None blobs)

let locate m =
  all_blobs m |> List.filter (fun b -> not (on_player_sprite b)) |> pick_largest

let locate_diff ~before ~after =
  let static = all_blobs before in
  all_blobs after
  |> List.filter (fun b ->
         (not (on_player_sprite b)) && not (near_any_before static b))
  |> pick_largest

let dir_of_offset { dx; dy; _ } =
  if dy < 0 then Corridor_nav.North
  else if dy > 0 then Corridor_nav.South
  else if dx > 0 then Corridor_nav.East
  else Corridor_nav.West

let direction m = Option.map dir_of_offset (locate m)
