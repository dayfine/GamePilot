module PB = Switch_home.Picture_box
module CS = Switch_home.Color_share

let tl_id = "bdsp_mine_cnt_tl"
let ml_id = "bdsp_mine_cnt_ml"
let bl_id = "bdsp_mine_cnt_bl"
let br_id = "bdsp_mine_cnt_br"

(* Normalized digit bounding box measured on 640x360 Console A captures:
   x = 272..280 (0.4250..0.4375), y = 302..316 (0.8389..0.8778). *)
let digit_x = 0.4250
let digit_y = 0.8389
let half_w = 0.00625
let third_h = 0.0130
let tl_box : Wire.box = { x = digit_x; y = digit_y; w = half_w; h = third_h }

let ml_box : Wire.box =
  { x = digit_x; y = digit_y +. third_h; w = half_w; h = third_h }

let bl_box : Wire.box =
  { x = digit_x; y = digit_y +. (2. *. third_h); w = half_w; h = third_h }

let br_box : Wire.box =
  {
    x = digit_x +. half_w;
    y = digit_y +. (2. *. third_h);
    w = half_w;
    h = third_h;
  }

let ch_zero = 0
let ink_max = 130
let ink_min_rgb = (ch_zero, ch_zero, ch_zero)
let ink_max_rgb = (ink_max, ink_max, ink_max)
let min_ink_sum = 0.50
let four_min_ml = 0.18
let four_max_tl = 0.20
let two_three_min_tl = 0.22
let three_min_br = 0.25
let two_min_bl_br_diff = 0.15
let count_two = 2
let count_three = 3
let count_four = 4

let count_probe ~picture ~id box =
  Option.map
    (fun b ->
      Wire.color_count_probe ~id ~box:b ~min:ink_min_rgb ~max:ink_max_rgb
        ~delivery:Every)
    (PB.clipped ~picture box)

let probes ~picture =
  List.filter_map Fun.id
    [
      count_probe ~picture ~id:tl_id tl_box;
      count_probe ~picture ~id:ml_id ml_box;
      count_probe ~picture ~id:bl_id bl_box;
      count_probe ~picture ~id:br_id br_box;
    ]

let classify_shares ~tl ~ml ~bl ~br =
  if tl +. ml +. bl +. br < min_ink_sum then None
  else if ml >= four_min_ml && tl <= four_max_tl then Some count_four
  else if
    tl >= two_three_min_tl && br < three_min_br
    && bl -. br >= two_min_bl_br_diff
  then Some count_two
  else if tl >= two_three_min_tl && br >= three_min_br then Some count_three
  else None

let read m =
  match
    (CS.read m tl_id, CS.read m ml_id, CS.read m bl_id, CS.read m br_id)
  with
  | Some tl, Some ml, Some bl, Some br -> classify_shares ~tl ~ml ~bl ~br
  | _ -> None
