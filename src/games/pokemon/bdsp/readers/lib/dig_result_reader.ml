open Bdsp_underground
module PB = Switch_home.Picture_box
module SC = Switch_home.Solid_color
module CS = Switch_home.Color_share

let spot_left_id = "bdsp_dig_spot_left"
let spot_right_id = "bdsp_dig_spot_right"
let icon_stats_id = "bdsp_dig_icon_stats"
let icon_pink_id = "bdsp_dig_icon_pink"
let icon_blue_id = "bdsp_dig_icon_blue"
let icon_red_id = "bdsp_dig_icon_red"
let icon_green_id = "bdsp_dig_icon_green"
let icon_gold_id = "bdsp_dig_icon_gold"

(* Placed in the outer smooth tan margins so multi-item spotlights never
   overlap the background probes (calibrated on run-12/001985 & run-16/006028:
   mean ~ [152, 133, 103], std_sum ~ 10..12). *)
let spot_left_box : Wire.box = { x = 0.24; y = 0.45; w = 0.08; h = 0.10 }
let spot_right_box : Wire.box = { x = 0.68; y = 0.45; w = 0.08; h = 0.10 }
let icon_box : Wire.box = { x = 0.44; y = 0.40; w = 0.12; h = 0.18 }
let spot_min_r = 140.
let spot_min_g = 120.
let spot_min_b = 90.
let spot_min_r_over_b = 30.
let spot_max_std = 65.
let icon_min_std_sum = 20.
let ch_max = 255
let ch_zero = 0

(* Calibrated from Console A run-12/001985 (Shard S = 0.0172), run-12/004369 &
   005847 (Shard L = 0.0284..0.0310), run-8/000144 (Heat Rock = 0.0016), and
   run-12/006057 (Red Sphere = 0.0006). *)
let pink_r_min = 180
let pink_g_max = 140
let pink_b_min = 165
let blue_r_max = 110
let blue_g_min = 60
let blue_g_max = 200
let blue_b_min = 145
let red_r_min = 165
let red_gb_max = 115
let green_r_max = 115
let green_g_min = 130
let green_b_max = 125
let gold_r_min = 195
let gold_g_min = 150
let gold_g_max = 245
let gold_b_max = 105
let pink_min = (pink_r_min, ch_zero, pink_b_min)
let pink_max = (ch_max, pink_g_max, ch_max)
let blue_min = (ch_zero, blue_g_min, blue_b_min)
let blue_max = (blue_r_max, blue_g_max, ch_max)
let red_min = (red_r_min, ch_zero, ch_zero)
let red_max = (ch_max, red_gb_max, red_gb_max)
let green_min = (ch_zero, green_g_min, ch_zero)
let green_max = (green_r_max, ch_max, green_b_max)
let gold_min = (gold_r_min, gold_g_min, ch_zero)
let gold_max = (ch_max, gold_g_max, gold_b_max)
let shard_l_min_share = 0.024
let shard_s_min_share = 0.010
let sphere_min_share = 0.025
let gold_min_share = 0.035

let stats_probe ~picture ~id box =
  Option.map
    (fun b -> Wire.color_stats_probe ~id ~box:b ~delivery:Every)
    (PB.clipped ~picture box)

let count_probe ~picture ~id ~min ~max box =
  Option.map
    (fun b -> Wire.color_count_probe ~id ~box:b ~min ~max ~delivery:Every)
    (PB.clipped ~picture box)

let probes ~picture =
  List.filter_map Fun.id
    [
      stats_probe ~picture ~id:spot_left_id spot_left_box;
      stats_probe ~picture ~id:spot_right_id spot_right_box;
      stats_probe ~picture ~id:icon_stats_id icon_box;
      count_probe ~picture ~id:icon_pink_id ~min:pink_min ~max:pink_max icon_box;
      count_probe ~picture ~id:icon_blue_id ~min:blue_min ~max:blue_max icon_box;
      count_probe ~picture ~id:icon_red_id ~min:red_min ~max:red_max icon_box;
      count_probe ~picture ~id:icon_green_id ~min:green_min ~max:green_max
        icon_box;
      count_probe ~picture ~id:icon_gold_id ~min:gold_min ~max:gold_max icon_box;
    ]

let is_tan_spot m id =
  match SC.stats m id with
  | Some s ->
      s.mean.r >= spot_min_r && s.mean.g >= spot_min_g && s.mean.b >= spot_min_b
      && s.mean.r -. s.mean.b >= spot_min_r_over_b
      && SC.sum s.stddev <= spot_max_std
  | None -> false

let has_icon_present m =
  match SC.stats m icon_stats_id with
  | Some s -> SC.sum s.stddev >= icon_min_std_sum
  | None -> false

let on_item_spotlight m =
  is_tan_spot m spot_left_id
  && is_tan_spot m spot_right_id
  && has_icon_present m

let share m id = Option.value (CS.read m id) ~default:0.

let classify_icon m =
  let pink = share m icon_pink_id in
  let blue = share m icon_blue_id in
  let red = share m icon_red_id in
  let green = share m icon_green_id in
  let gold = share m icon_gold_id in
  if pink >= shard_l_min_share then Mining_counters.Shard_l
  else if pink >= shard_s_min_share then Mining_counters.Shard_s
  else if
    blue >= sphere_min_share || red >= sphere_min_share
    || green >= sphere_min_share
  then Mining_counters.Sphere
  else if gold >= gold_min_share then Mining_counters.Statue_box
  else Mining_counters.Other_treasure

let read m = if on_item_spotlight m then Some (classify_icon m) else None

let treasure_name = function
  | Mining_counters.Shard_s -> "Mysterious Shard S"
  | Shard_l -> "Mysterious Shard L"
  | Sphere -> "Sphere"
  | Evolution_stone -> "Evolution Stone"
  | Fossil -> "Fossil"
  | Statue_box -> "Statue Box"
  | Other_treasure -> "Other Treasure"
