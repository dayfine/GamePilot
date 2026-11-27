module PB = Switch.Picture_box
module SC = Switch.Solid_color

type probe_ids = {
  bottom : string;
  left_white : string;
  left_border : string;
  right_border : string;
}

let ids =
  {
    bottom = "bdsp_bdlg_bot";
    left_white = "bdsp_bdlg_lw";
    left_border = "bdsp_bdlg_l";
    right_border = "bdsp_bdlg_r";
  }

let border_min_stddev_sum = 50.

let boxes : (string * Wire.box) list =
  [
    (ids.bottom, { x = 0.50; y = 0.91; w = 0.40; h = 0.05 });
    (ids.left_white, { x = 0.07; y = 0.835; w = 0.008; h = 0.12 });
    (ids.left_border, { x = 0.04; y = 0.835; w = 0.02; h = 0.12 });
    (ids.right_border, { x = 0.965; y = 0.835; w = 0.02; h = 0.12 });
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
  is_white m ids.left_white && is_white m ids.bottom
  && border_ok m ids.left_border
  && border_ok m ids.right_border
