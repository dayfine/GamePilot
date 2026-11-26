let top_id = "start_menu.top"
let left_id = "start_menu.left"

(* SelectionArrowDetector::arrow_box_for_position, POKEDEX to EXIT. *)
let row_boxes : Wire.box list =
  [
    { x = 0.727692; y = 0.0523077; w = 0.0369231; h = 0.0778846 };
    { x = 0.727692; y = 0.1457692; w = 0.0369231; h = 0.0778846 };
    { x = 0.727692; y = 0.2392307; w = 0.0369231; h = 0.0778846 };
    { x = 0.727692; y = 0.3378846; w = 0.0369231; h = 0.0778846 };
    { x = 0.727692; y = 0.4261538; w = 0.0369231; h = 0.0778846 };
    { x = 0.727692; y = 0.5248076; w = 0.0369231; h = 0.0778846 };
    { x = 0.727692; y = 0.6182692; w = 0.0369231; h = 0.0778846 };
  ]

let cursor = Cursor_column.make ~prefix:"start_menu" row_boxes

(* The frame's left edge at each row's height (the fork's left box, cut per
   row): white where the menu reaches. *)
let edge_id index = Printf.sprintf "start_menu.edge%d" index
let edge_box (b : Wire.box) : Wire.box = { b with x = 0.728365; w = 0.003365 }

let probes =
  Solid_color.probe ~id:top_id
    { x = 0.728365; y = 0.043509; w = 0.238462; h = 0.006490 }
  :: Solid_color.probe ~id:left_id
       { x = 0.728365; y = 0.050000; w = 0.003365; h = 0.427644 }
  :: Cursor_column.probes cursor
  @ List.mapi
      (fun index b -> Solid_color.probe ~id:(edge_id index) (edge_box b))
      row_boxes

let white m id = Solid_color.holds m id (fun s -> Solid_color.is_white s)

(* Rows from the top while the edge beside them is white. *)
let menu_rows m =
  let rec count index =
    if index < List.length row_boxes && white m (edge_id index) then
      count (index + 1)
    else index
  in
  count 0

let cursor_row m =
  if white m top_id && white m left_id then
    Cursor_column.row ~rows:(menu_rows m) cursor m
  else None

let start_menu_open m = Option.is_some (cursor_row m)
