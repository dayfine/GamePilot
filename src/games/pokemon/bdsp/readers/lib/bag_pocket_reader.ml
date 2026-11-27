module PB = Switch.Picture_box
module SC = Switch.Solid_color

type pocket =
  | Medicine
  | Poke_balls
  | Battle_items
  | Berries
  | Items
  | Tms
  | Treasures
  | Key_items

type bag_header_spec = {
  id : string;
  box : Wire.box;
  min_green : float;
  min_green_lead_r : float;
  min_green_lead_b : float;
  max_stddev_sum : float;
}

type mart_limits = {
  pocket_count : int;
  half_pockets : int;
  min_qty : int;
  max_qty : int;
  ten_step : int;
  overshoot_threshold : int;
}

let limits : mart_limits =
  {
    pocket_count = 8;
    half_pockets = 4;
    min_qty = 1;
    max_qty = 99;
    ten_step = 10;
    overshoot_threshold = 6;
  }

let bag_header : bag_header_spec =
  {
    id = "bdsp_bag_header";
    box = { x = 0.62; y = 0.03; w = 0.30; h = 0.04 };
    min_green = 140.;
    min_green_lead_r = 30.;
    min_green_lead_b = 15.;
    max_stddev_sum = 120.;
  }

let pocket_index = function
  | Medicine -> 0
  | Poke_balls -> 1
  | Battle_items -> 2
  | Berries -> 3
  | Items -> 4
  | Tms -> 5
  | Treasures -> 6
  | Key_items -> 7

let pocket_steps ~from ~to_ =
  let n = limits.pocket_count in
  let diff = (pocket_index to_ - pocket_index from + n) mod n in
  if diff = 0 then `Stay
  else if diff <= limits.half_pockets then `Right diff
  else `Left (n - diff)

let mart_quantity_steps ~target_qty =
  let qty = max limits.min_qty (min limits.max_qty target_qty) in
  let delta = qty - limits.min_qty in
  let tens = delta / limits.ten_step in
  let rem = delta mod limits.ten_step in
  let can_overshoot =
    limits.min_qty + ((tens + 1) * limits.ten_step) <= limits.max_qty
  in
  if rem >= limits.overshoot_threshold && can_overshoot then
    let downs = limits.ten_step - rem in
    [ `Right (tens + 1); `Down downs ]
  else
    let rights = if tens > 0 then [ `Right tens ] else [] in
    let ups = if rem > 0 then [ `Up rem ] else [] in
    rights @ ups

let bag_open_probes ~picture =
  match PB.clipped ~picture bag_header.box with
  | Some box ->
      [ Wire.color_stats_probe ~id:bag_header.id ~box ~delivery:Every ]
  | None -> []

let bag_open (m : Effects.measurements) =
  match SC.stats m bag_header.id with
  | None -> false
  | Some s ->
      let mean = s.mean in
      mean.g >= bag_header.min_green
      && mean.g -. mean.r >= bag_header.min_green_lead_r
      && mean.g -. mean.b >= bag_header.min_green_lead_b
      && SC.sum s.stddev <= bag_header.max_stddev_sum
