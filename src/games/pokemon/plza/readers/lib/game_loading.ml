let box left top width height =
  Native_box.of_fractions { left; top; width; height }

let loading_boxes =
  [
    ("game_loading.top", box 0.2 0.2 0.6 0.1);
    ("game_loading.bottom", box 0.2 0.7 0.6 0.1);
  ]

let entering_box = ("game_loading.entering", box 0.1 0.04 0.8 0.3)

let probes ~picture =
  List.concat_map
    (fun (id, b) -> Box_color.probe ~picture ~id b)
    (entering_box :: loading_boxes)

(* is_black's defaults. *)
let black_max_sum = 100.0
let black_max_stddev_sum = 10.0
let sum (c : Wire.rgb) = c.r +. c.g +. c.b

let black m id =
  match Box_color.read m id with
  | Some s ->
      sum s.mean <= black_max_sum && sum s.stddev <= black_max_stddev_sum
  | None -> false

let loading m = List.for_all (fun (id, _) -> black m id) loading_boxes
let entering m = black m (fst entering_box)
