let right_id = "dialog.right"
let top_id = "dialog.top"
let bottom_id = "dialog.bottom"
let frame_id = "dialog.frame"
let selection_id = "dialog.selection"

let edge_boxes : (string * Wire.box) list =
  [
    (right_id, { x = 0.923385; y = 0.748077; w = 0.00615385; h = 0.204577 });
    (top_id, { x = 0.0704615; y = 0.741846; w = 0.859077; h = 0.00623077 });
    (bottom_id, { x = 0.0716923; y = 0.943308; w = 0.851692; h = 0.00934615 });
    (frame_id, { x = 0.0704615; y = 0.7288; w = 0.859077; h = 0.0048 });
    (selection_id, { x = 0.885231; y = 0.447962; w = 0.016; h = 0.2025 });
  ]

(* The fork's arrow test: the text area's pixels in its red range, (164, 0, 0)
   to (255, 114, 87), whose mean must be far redder than green and blue. *)
let arrow_id = "dialog.arrow"

let text_area : Wire.box =
  { x = 0.0630769; y = 0.750154; w = 0.870154; h = 0.200423 }

let channel_max = 255
let arrow_min_red = 164
let arrow_max_green = 114
let arrow_max_blue = 87
let arrow_min = (arrow_min_red, 0, 0)
let arrow_max = (channel_max, arrow_max_green, arrow_max_blue)
let min_red_excess = 160.

let probes =
  Wire.color_count_probe ~id:arrow_id ~box:text_area ~delivery:Every
    ~min:arrow_min ~max:arrow_max
  :: List.map (fun (id, b) -> Solid_color.probe ~id b) edge_boxes

let frame_min_white_sum = 720.
let white m id = Solid_color.holds m id (fun s -> Solid_color.is_white s)
let edges_white m = white m right_id && white m top_id && white m bottom_id

let dialog_up m =
  edges_white m
  && not
       (Solid_color.holds m frame_id
          (Solid_color.is_white ~min_sum:frame_min_white_sum))

let arrow_red m =
  match Effects.probe m arrow_id with
  | Some (Wire.Color_count { mean = Some mean; _ }) ->
      Float.min (mean.r -. mean.g) (mean.r -. mean.b) > min_red_excess
  | Some _ | None -> false

let advance_arrow m = dialog_up m && arrow_red m
let selection_dialog m = dialog_up m && white m selection_id
