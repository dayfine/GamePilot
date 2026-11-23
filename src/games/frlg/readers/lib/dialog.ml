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

(* The arrow strips, in game pixels of the 240x160 picture: two text lines
   (y 120-135 and 135-150), strips 17 px wide every 8 px from x 15, so the 9 px
   wide arrow lies wholly inside one of them wherever it is. *)
let picture_w = 240.
let picture_h = 160.
let strip_left_px = 15.
let strip_w_px = 17.
let strip_step_px = 8.
let strips_per_line = 25
let first_line_top_px = 120.
let line_h_px = 15.
let line_tops_px = [ first_line_top_px; first_line_top_px +. line_h_px ]

let arrow_strips : (string * Wire.box) list =
  List.concat_map
    (fun top ->
      List.init strips_per_line (fun i ->
          let left = strip_left_px +. (float_of_int i *. strip_step_px) in
          ( Printf.sprintf "dialog.arrow.%.0f.%d" top i,
            {
              Wire.x = left /. picture_w;
              y = top /. picture_h;
              w = strip_w_px /. picture_w;
              h = line_h_px /. picture_h;
            } )))
    line_tops_px

let probes screen =
  List.map
    (fun (id, b) -> Game_screen.color_stats_probe screen ~id b)
    (edge_boxes @ arrow_strips)

let frame_min_white_sum = 720.
let min_red_excess = 10.
let white m id = Solid_color.holds m id (fun s -> Solid_color.is_white s)
let edges_white m = white m right_id && white m top_id && white m bottom_id

let dialog_up m =
  edges_white m
  && not
       (Solid_color.holds m frame_id
          (Solid_color.is_white ~min_sum:frame_min_white_sum))

let red (s : Solid_color.stats) =
  Float.min (s.mean.r -. s.mean.g) (s.mean.r -. s.mean.b) >= min_red_excess

let advance_arrow m =
  dialog_up m
  && List.exists (fun (id, _) -> Solid_color.holds m id red) arrow_strips

let selection_dialog m = dialog_up m && white m selection_id
