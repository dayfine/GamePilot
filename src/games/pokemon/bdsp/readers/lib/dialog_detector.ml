module PB = Switch.Picture_box
module SC = Switch.Solid_color

let id_left_white = "bdsp_dlg_lw"
let id_left = "bdsp_dlg_l"
let id_right_white = "bdsp_dlg_rw"
let id_right_white_low = "bdsp_dlg_rwl"
let id_right = "bdsp_dlg_r"
let border_min_stddev_sum = 30.

let boxes : (string * Wire.box) list =
  [
    (id_left_white, { x = 0.21; y = 0.835; w = 0.008; h = 0.12 });
    (id_left, { x = 0.18; y = 0.835; w = 0.02; h = 0.12 });
    (id_right_white, { x = 0.785; y = 0.835; w = 0.008; h = 0.12 });
    (id_right_white_low, { x = 0.785; y = 0.915; w = 0.008; h = 0.04 });
    (id_right, { x = 0.822; y = 0.835; w = 0.02; h = 0.12 });
  ]

let probes ~picture =
  List.filter_map
    (fun (id, box) ->
      Option.map
        (fun box -> Wire.color_stats_probe ~id ~box ~delivery:Every)
        (PB.clipped ~picture box))
    boxes

let is_white m id =
  match SC.stats m id with Some s -> SC.is_white s | None -> false

let border_ok m id =
  match SC.stats m id with
  | Some s -> SC.sum s.stddev >= border_min_stddev_sum
  | None -> false

let shown m =
  is_white m id_left_white
  && (is_white m id_right_white || is_white m id_right_white_low)
  && border_ok m id_left && border_ok m id_right
