module PB = Switch.Picture_box
module SC = Switch.Solid_color

type screen = Action_menu | Forced_switch | Dialog | Black | Other

type hp_bar_layout = {
  prefix : string;
  x : float;
  y : float;
  w : float;
  h : float;
  segments : int;
}

type hp_thresholds = {
  min_chroma : float;
  min_brightness : float;
  max_stddev_sum : float;
}

type color_target = {
  id : string;
  box : Wire.box;
  r_share : float;
  g_share : float;
  b_share : float;
  max_dist : float;
  min_rgb_sum : float;
  max_rgb_sum : float;
}

let foe_bar : hp_bar_layout =
  {
    prefix = "bdsp_foe_hp_";
    x = 0.767;
    y = 0.115;
    w = 0.199;
    h = 0.013;
    segments = 10;
  }

let player_bar : hp_bar_layout =
  {
    prefix = "bdsp_ply_hp_";
    x = 0.046;
    y = 0.882;
    w = 0.199;
    h = 0.013;
    segments = 10;
  }

let hp_thresh : hp_thresholds =
  { min_chroma = 35.; min_brightness = 90.; max_stddev_sum = 140. }

let sleep_badge : color_target =
  {
    id = "bdsp_foe_slp";
    box = { x = 0.889; y = 0.063; w = 0.090; h = 0.043 };
    r_share = 0.232;
    g_share = 0.334;
    b_share = 0.433;
    max_dist = 0.09;
    min_rgb_sum = 380.;
    max_rgb_sum = 620.;
  }

let switch_header : color_target =
  {
    id = "bdsp_switch_hdr";
    box = { x = 0.050; y = 0.030; w = 0.250; h = 0.040 };
    r_share = 0.14;
    g_share = 0.44;
    b_share = 0.42;
    max_dist = 0.14;
    min_rgb_sum = 220.;
    max_rgb_sum = 620.;
  }

let seg_id bar idx = Printf.sprintf "%s%d" bar.prefix idx

let color_probe ~picture ~id box =
  Option.map
    (fun box -> Wire.color_stats_probe ~id ~box ~delivery:Every)
    (PB.clipped ~picture box)

let segment_probe ~picture bar seg_w idx =
  let box : Wire.box =
    {
      x = bar.x +. (float_of_int idx *. seg_w);
      y = bar.y;
      w = seg_w;
      h = bar.h;
    }
  in
  color_probe ~picture ~id:(seg_id bar idx) box

let bar_probes ~picture bar =
  let seg_w = bar.w /. float_of_int bar.segments in
  List.init bar.segments (segment_probe ~picture bar seg_w)
  |> List.filter_map Fun.id

let probes ~picture =
  let badges =
    List.filter_map Fun.id
      [
        color_probe ~picture ~id:sleep_badge.id sleep_badge.box;
        color_probe ~picture ~id:switch_header.id switch_header.box;
      ]
  in
  bar_probes ~picture foe_bar @ bar_probes ~picture player_bar @ badges

let all_battle_probes ~picture =
  probes ~picture
  @ Battle_detector.probes ~picture
  @ Dialog_detector.probes ~picture
  @ Switch.Black_screen.probes ~picture

let is_filled_hp_segment (s : SC.stats) =
  let max_c = Float.max s.mean.r (Float.max s.mean.g s.mean.b) in
  let min_c = Float.min s.mean.r (Float.min s.mean.g s.mean.b) in
  let chroma = max_c -. min_c in
  chroma >= hp_thresh.min_chroma
  && max_c >= hp_thresh.min_brightness
  && SC.sum s.stddev <= hp_thresh.max_stddev_sum

let read_hp_bar m bar =
  let rec loop idx seen filled =
    if idx >= bar.segments then
      if seen = 0 then None
      else Some (float_of_int filled /. float_of_int bar.segments)
    else
      match SC.stats m (seg_id bar idx) with
      | None -> loop (idx + 1) seen filled
      | Some s ->
          let filled = if is_filled_hp_segment s then filled + 1 else filled in
          loop (idx + 1) (seen + 1) filled
  in
  loop 0 0 0

let foe_hp_ratio m = read_hp_bar m foe_bar
let player_hp_ratio m = read_hp_bar m player_bar

let matches_target_opt m (t : color_target) =
  match SC.stats m t.id with
  | None -> None
  | Some s ->
      let avg_sum = SC.sum s.mean in
      if avg_sum < t.min_rgb_sum || avg_sum > t.max_rgb_sum then Some false
      else
        let dr = (s.mean.r /. avg_sum) -. t.r_share in
        let dg = (s.mean.g /. avg_sum) -. t.g_share in
        let db = (s.mean.b /. avg_sum) -. t.b_share in
        Some (sqrt ((dr *. dr) +. (dg *. dg) +. (db *. db)) <= t.max_dist)

let foe_asleep m = matches_target_opt m sleep_badge

let forced_switch_shown m =
  Option.value ~default:false (matches_target_opt m switch_header)

let classify_screen m =
  if Battle_detector.shown m then Action_menu
  else if forced_switch_shown m then Forced_switch
  else if Dialog_detector.shown m then Dialog
  else if Switch.Black_screen.shown m then Black
  else Other
