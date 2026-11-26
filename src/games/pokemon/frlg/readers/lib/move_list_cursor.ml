let rows = 5
let row_step = 28.
let row_id n = Printf.sprintf "move_list.row%d" n
let top_row : Wire.box = { x = 120.; y = 24.; w = 2.; h = 16. }

let row_box n =
  Game_pixels.box { top_row with y = top_row.y +. (row_step *. float_of_int n) }

let edge_red : Color_count.range =
  { low = { r = 201; g = 0; b = 0 }; high = { r = 255; g = 139; b = 89 } }

let min_red_share = 0.5
let all_rows = List.init rows Fun.id

let probes =
  List.map
    (fun n -> Color_count.probe ~id:(row_id n) (row_box n) edge_red)
    all_rows

let edge_shows m n =
  match Color_count.share m (row_id n) with
  | Some share -> share > min_red_share
  | None -> false

let row m =
  match List.filter (edge_shows m) all_rows with [ n ] -> Some n | _ -> None
