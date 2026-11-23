let corners : (string * Wire.box) list =
  [
    ("dark.top_left", { x = 0.; y = 0.; w = 0.13; h = 0.2 });
    ("dark.top_right", { x = 0.87; y = 0.; w = 0.13; h = 0.2 });
    ("dark.bottom_left", { x = 0.; y = 0.8; w = 0.13; h = 0.2 });
    ("dark.bottom_right", { x = 0.87; y = 0.8; w = 0.13; h = 0.2 });
  ]

let middle_id = "dark.middle"
let middle : Wire.box = { x = 0.45; y = 0.42; w = 0.1; h = 0.16 }

let probes screen =
  List.map
    (fun (id, b) -> Game_screen.color_stats_probe screen ~id b)
    ((middle_id, middle) :: corners)

(* The fork's values, set from the GBA screen, not measured on frames. *)
let max_corner_sum = 45.
let min_middle_sum = 120.

let brightness_below m id limit =
  Solid_color.holds m id (fun s -> Solid_color.sum s.mean < limit)

let dark_corners m =
  List.for_all (fun (id, _) -> brightness_below m id max_corner_sum) corners
  && Solid_color.holds m middle_id (fun s ->
         Solid_color.sum s.mean >= min_middle_sum)
