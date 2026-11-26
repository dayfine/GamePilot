module PB = Switch_home.Picture_box
module SC = Switch_home.Solid_color

let stripe_top = 0.110
let stripe_top_below_banner = 0.170
let stripe_bottom = 0.598
let stripe_left = 0.166
let stripe_step = 0.166
let stripe_width = 0.015
let cross_box : Wire.box = { x = 0.20; y = 0.15; w = 0.60; h = 0.37 }
let cross_min_stddev_sum = 100.

let stripe_names =
  [|
    "bdsp_menu_l0";
    "bdsp_menu_l1";
    "bdsp_menu_l2";
    "bdsp_menu_l3";
    "bdsp_menu_l4";
  |]

let cross_name = "bdsp_menu_cross"

let stripe_box ~skip_new_banner idx : Wire.box =
  let top = if skip_new_banner then stripe_top_below_banner else stripe_top in
  {
    x = stripe_left +. (stripe_step *. float_of_int idx);
    y = top;
    w = stripe_width;
    h = stripe_bottom -. top;
  }

let color_probe ~picture ~id box =
  Option.map
    (fun box -> Wire.color_stats_probe ~id ~box ~delivery:Every)
    (PB.clipped ~picture box)

let probes ~picture ?(skip_new_banner = false) () =
  let stripes =
    Array.to_list
      (Array.mapi
         (fun idx id ->
           color_probe ~picture ~id (stripe_box ~skip_new_banner idx))
         stripe_names)
  in
  let cross = color_probe ~picture ~id:cross_name cross_box in
  List.filter_map Fun.id (cross :: stripes)

let stripe_is_white (m : Effects.measurements) name =
  match SC.stats m name with Some s -> SC.is_white s | None -> false

let shown (m : Effects.measurements) =
  let all_white = Array.for_all (stripe_is_white m) stripe_names in
  if not all_white then false
  else
    match SC.stats m cross_name with
    | Some s -> SC.sum s.stddev >= cross_min_stddev_sum
    | None -> false
