open Solid_color

let top_id = "close_game.top"
let left_id = "close_game.left"
let text_id = "close_game.text_row"

let frame_boxes : (string * Wire.box) list =
  [
    (top_id, { x = 0.226358; y = 0.272648; w = 0.407445; h = 0.033989 });
    (left_id, { x = 0.225; y = 0.275; w = 0.015; h = 0.350 });
    (text_id, { x = 0.330986; y = 0.649052; w = 0.342052; h = 0.051878 });
  ]

let probes ~picture =
  List.filter_map
    (fun (id, frame_box) ->
      Option.map
        (fun box -> Wire.color_stats_probe ~id ~box ~delivery:Every)
        (Picture_box.clipped ~picture frame_box))
    frame_boxes

let grey_max_sum = 300.
let white_above_sum = 500.
let max_flat_stddev = 20.
let min_text_stddev = 50.
let max_same_color = 20.

(* CloseGameDetector::detect. *)
let popup ~top ~left ~text =
  let total = sum top.mean in
  let theme =
    if total < grey_max_sum then Some false
    else if total > white_above_sum then Some true
    else None
  in
  let solid white s =
    if white then is_white s else is_grey ~min_sum:0. ~max_sum:grey_max_sum s
  in
  match theme with
  | None -> false
  | Some white ->
      sum top.stddev <= max_flat_stddev
      && sum left.stddev <= max_flat_stddev
      && sum text.stddev >= min_text_stddev
      && solid white top && solid white left
      && distance top.mean left.mean <= max_same_color

let shown m =
  match (stats m top_id, stats m left_id, stats m text_id) with
  | Some top, Some left, Some text -> popup ~top ~left ~text
  | _ -> false
