open Bdsp_underground
module PB = Switch_home.Picture_box
module BF = Wire.Blob_find

type offset = { dx : int; dy : int; dx_norm : float; dy_norm : float }

(* Two playfield boxes excluding the top-left minimap (x < 0.24, y < 0.36). *)
let right_box : Wire.box = { x = 0.24; y = 0.04; w = 0.72; h = 0.86 }
let left_box : Wire.box = { x = 0.08; y = 0.36; w = 0.16; h = 0.54 }
let right_probe_id = "bdsp_wall_star_right"
let left_probe_id = "bdsp_wall_star_left"

(* Measured from Console A captures run-2/000231.jpg, prev-run-2/000268.jpg,
   and run-1/000128.jpg: sparkle stars have bright white-gold cores in RGB
   (240..255, 230..255, 180..255) with area 30..2000 px on 1920x1080, while
   expanding cyan radar rings exceed 2500 px and red-orange wall torches have
   blue < 140 (or stay static across pre/post radar frames). *)
let star_r_min = 245
let star_g_min = 240
let star_b_min = 230
let star_ch_max = 255
let star_min_area = 50.
let star_max_area = 2500.
let game_w = 1920.
let game_h = 1080.
let player_x = 0.50
let player_y = 0.48
let player_exclude_dx = 0.035
let player_exclude_dy = 0.055
let align_deadzone_x = 0.035
let align_deadzone_y = 0.045
let static_match_px = 35.
let half = 0.5

let star_filter : BF.filter =
  {
    low = (star_r_min, star_g_min, star_b_min);
    high = (star_ch_max, star_ch_max, star_ch_max);
  }

let find_params =
  match
    BF.params ~filters:[ star_filter ] ~min_area:star_min_area
      ~max_area:star_max_area ()
  with
  | Ok p -> p
  | Error _ ->
      {
        BF.filters = [ star_filter ];
        min_area = star_min_area;
        max_area = Some star_max_area;
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
let blob_center (b : BF.blob) = (b.x +. (b.w *. half), b.y +. (b.h *. half))
let blob_area (b : BF.blob) = b.w *. b.h *. b.fill

let on_player_sprite (b : BF.blob) =
  let cx, cy = blob_center b in
  let nx = cx /. game_w and ny = cy /. game_h in
  Float.abs (nx -. player_x) < player_exclude_dx
  && Float.abs (ny -. player_y) < player_exclude_dy

let near_any_before before (b : BF.blob) =
  let cx, cy = blob_center b in
  List.exists
    (fun prev ->
      let px, py = blob_center prev in
      Float.abs (cx -. px) <= static_match_px
      && Float.abs (cy -. py) <= static_match_px)
    before

let sign_with_deadzone dz v = if v < -.dz then -1 else if v > dz then 1 else 0

let offset_of_blob (b : BF.blob) =
  let cx, cy = blob_center b in
  let dx_norm = (cx /. game_w) -. player_x in
  let dy_norm = (cy /. game_h) -. player_y in
  {
    dx = sign_with_deadzone align_deadzone_x dx_norm;
    dy = sign_with_deadzone align_deadzone_y dy_norm;
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
