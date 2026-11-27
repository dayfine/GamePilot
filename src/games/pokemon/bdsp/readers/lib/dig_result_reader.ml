open Bdsp_underground
module PB = Switch_home.Picture_box
module SC = Switch_home.Solid_color
module CS = Switch_home.Color_share

type rgb_band = {
  min_r : int;
  max_r : int;
  min_g : int;
  max_g : int;
  min_b : int;
  max_b : int;
}

type spotlight_config = {
  left_box : Wire.box;
  right_box : Wire.box;
  icon_box : Wire.box;
  min_r : float;
  min_g : float;
  min_b : float;
  min_r_over_b : float;
  max_std : float;
  icon_min_std : float;
}

type share_thresholds = {
  shard_l : float;
  shard_s : float;
  sphere : float;
  gold : float;
}

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
let spot =
  {
    left_box = { x = 0.24; y = 0.45; w = 0.08; h = 0.10 };
    right_box = { x = 0.68; y = 0.45; w = 0.08; h = 0.10 };
    icon_box = { x = 0.44; y = 0.40; w = 0.12; h = 0.18 };
    min_r = 140.;
    min_g = 120.;
    min_b = 90.;
    min_r_over_b = 30.;
    max_std = 65.;
    icon_min_std = 20.;
  }

(* Calibrated from Console A run-12/001985 (Shard S = 0.0172), run-12/004369 &
   005847 (Shard L = 0.0284..0.0310), run-8/000144 (Heat Rock = 0.0016), and
   run-12/006057 (Red Sphere = 0.0006). *)
let pink_band =
  { min_r = 180; max_r = 255; min_g = 0; max_g = 140; min_b = 165; max_b = 255 }

let blue_band =
  { min_r = 0; max_r = 110; min_g = 60; max_g = 200; min_b = 145; max_b = 255 }

let red_band =
  { min_r = 165; max_r = 255; min_g = 0; max_g = 115; min_b = 0; max_b = 115 }

let green_band =
  { min_r = 0; max_r = 115; min_g = 130; max_g = 255; min_b = 0; max_b = 125 }

let gold_band =
  { min_r = 195; max_r = 255; min_g = 150; max_g = 245; min_b = 0; max_b = 105 }

let min_share =
  { shard_l = 0.024; shard_s = 0.010; sphere = 0.025; gold = 0.035 }

let stats_probe ~picture ~id box =
  Option.map
    (fun b -> Wire.color_stats_probe ~id ~box:b ~delivery:Every)
    (PB.clipped ~picture box)

let count_probe ~picture ~id (band : rgb_band) box =
  let min = (band.min_r, band.min_g, band.min_b) in
  let max = (band.max_r, band.max_g, band.max_b) in
  Option.map
    (fun b -> Wire.color_count_probe ~id ~box:b ~min ~max ~delivery:Every)
    (PB.clipped ~picture box)

let probes ~picture =
  List.filter_map Fun.id
    [
      stats_probe ~picture ~id:spot_left_id spot.left_box;
      stats_probe ~picture ~id:spot_right_id spot.right_box;
      stats_probe ~picture ~id:icon_stats_id spot.icon_box;
      count_probe ~picture ~id:icon_pink_id pink_band spot.icon_box;
      count_probe ~picture ~id:icon_blue_id blue_band spot.icon_box;
      count_probe ~picture ~id:icon_red_id red_band spot.icon_box;
      count_probe ~picture ~id:icon_green_id green_band spot.icon_box;
      count_probe ~picture ~id:icon_gold_id gold_band spot.icon_box;
    ]

let is_tan_spot m id =
  match SC.stats m id with
  | Some s ->
      s.mean.r >= spot.min_r && s.mean.g >= spot.min_g && s.mean.b >= spot.min_b
      && s.mean.r -. s.mean.b >= spot.min_r_over_b
      && SC.sum s.stddev <= spot.max_std
  | None -> false

let has_icon_present m =
  match SC.stats m icon_stats_id with
  | Some s -> SC.sum s.stddev >= spot.icon_min_std
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
  if pink >= min_share.shard_l then Mining_counters.Shard_l
  else if pink >= min_share.shard_s then Mining_counters.Shard_s
  else if
    blue >= min_share.sphere || red >= min_share.sphere
    || green >= min_share.sphere
  then Mining_counters.Sphere
  else if gold >= min_share.gold then Mining_counters.Statue_box
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
