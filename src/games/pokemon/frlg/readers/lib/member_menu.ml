(* Measured on mGBA frames of the four-row menu: the arrow in x 153-157 and
   9 rows from 4 above a row's text, CANCEL's text from y 141, rows 16 apart
   upward; the window's white inside from x 150. *)
let bottom_row_top = 140.
let row_pitch = 16.
let max_rows = 8
let arrow_left = 152.
let arrow_width = 7.
let arrow_height = 11.
let inside_left = 150.
let inside_width = 2.

let row_box k =
  Game_pixels.box
    {
      x = arrow_left;
      y = bottom_row_top -. (row_pitch *. float_of_int k);
      w = arrow_width;
      h = arrow_height;
    }

let edge_id k = Printf.sprintf "member_menu.edge%d" k

let edge_box (b : Wire.box) : Wire.box =
  {
    b with
    x = inside_left /. Game_pixels.width;
    w = inside_width /. Game_pixels.width;
  }

let row_boxes = List.init max_rows row_box
let cursor = Cursor_column.make ~prefix:"member_menu" row_boxes

let probes =
  Cursor_column.probes cursor
  @ List.mapi
      (fun k b -> Solid_color.probe ~id:(edge_id k) (edge_box b))
      row_boxes

let white m id = Solid_color.holds m id (fun s -> Solid_color.is_white s)

(* Rows from the bottom while the window's inside beside them is white. *)
let menu_rows m =
  let rec count k =
    if k < max_rows && white m (edge_id k) then count (k + 1) else k
  in
  count 0

let min_rows = 4

let rows m =
  let rows = menu_rows m in
  if rows >= min_rows then Some rows else None

(* The boxes count from the bottom; the reader from the top. *)
let cursor_row m =
  Option.bind (rows m) (fun rows ->
      Option.map (fun k -> rows - 1 - k) (Cursor_column.row ~rows cursor m))

let summary_row = 0
let switch_row ~rows = rows - 3
