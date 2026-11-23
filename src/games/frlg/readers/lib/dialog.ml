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

(* SelectionArrowDetector::arrow_box_for_position, YES and NO. *)
let yes_no_rows : Wire.box list =
  [
    { x = 0.69692; y = 0.4625; w = 0.037; h = 0.07788 };
    { x = 0.69692; y = 0.55; w = 0.037; h = 0.07788 };
  ]

let yes_no_arrow = Cursor_column.make ~prefix:"dialog.yes_no" yes_no_rows
let yes_no_probes = Cursor_column.probes yes_no_arrow

let probes =
  Wire.color_count_probe ~id:arrow_id ~box:text_area ~delivery:Every
    ~min:arrow_min ~max:arrow_max
  :: List.map (fun (id, b) -> Solid_color.probe ~id b) edge_boxes

let frame_min_white_sum = 720.
let white m id = Solid_color.holds m id (fun s -> Solid_color.is_white s)
let edges_white m = white m right_id && white m top_id && white m bottom_id

(* The box's frame line is a flat light grey, a channel sum of 603 to 686 in
   every capture, below white. Testing it for "not flat white" let a fade to
   white through: Pokemon Tower 5F's purified zone whitens the bright floor
   until the box's edges are white and the frame line near white but not flat
   (sums 738 to 763; mGBA, 2026-11-23, run 3 of the mg-04 flee fix). *)
let frame_below_white (s : Solid_color.stats) =
  Solid_color.sum s.mean < frame_min_white_sum

let dialog_up m =
  edges_white m && Solid_color.holds m frame_id frame_below_white

let arrow_red m =
  match Effects.probe m arrow_id with
  | Some (Wire.Color_count { mean = Some mean; _ }) ->
      Float.min (mean.r -. mean.g) (mean.r -. mean.b) > min_red_excess
  | Some _ | None -> false

let advance_arrow m = dialog_up m && arrow_red m
let selection_dialog m = dialog_up m && white m selection_id

let yes_no_cursor m =
  if selection_dialog m then
    Option.map (fun row -> row = 0) (Cursor_column.row yes_no_arrow m)
  else None
