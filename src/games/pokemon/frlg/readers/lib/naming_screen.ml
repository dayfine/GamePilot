type page = Upper | Lower | Others
type key = { row : int; col : int }

let rows = 4

(* sPageColumnXPos: the letters in groups of three and four 12 apart, the
   full stop and comma column apart; the others 22 apart. *)
type grid_geom = {
  letter_pitch : int;
  letter_first_group : int;
  letter_second_group : int;
  letter_second_x : int;
  letter_last_x : int;
  others_pitch : int;
  others_count : int;
  cursor_left : int;
  cursor_top : int;
  row_pitch : int;
  edge_dx : int;
  edge_dy : int;
  edge_width : int;
  edge_height : int;
}

let grid =
  {
    letter_pitch = 12;
    letter_first_group = 3;
    letter_second_group = 4;
    letter_second_x = 56;
    letter_last_x = 123;
    others_pitch = 22;
    others_count = 6;
    cursor_left = 38;
    cursor_top = 88;
    row_pitch = 16;
    edge_dx = 6;
    edge_dy = 6;
    edge_width = 3;
    edge_height = 5;
  }

let letter_columns =
  Array.of_list
    (List.init grid.letter_first_group (fun i -> grid.letter_pitch * i)
    @ List.init grid.letter_second_group (fun i ->
          grid.letter_second_x + (grid.letter_pitch * i))
    @ [ grid.letter_last_x ])

let others_columns =
  Array.init grid.others_count (fun i -> grid.others_pitch * i)

let columns_x = function
  | Upper | Lower -> letter_columns
  | Others -> others_columns

let columns page = Array.length (columns_x page)
let column_x page col = (columns_x page).(col)

(* SetCursorPos: the cursor sprite's centre. *)
let centre_x page col = column_x page col + grid.cursor_left
let centre_y row = grid.cursor_top + (grid.row_pitch * row)

(* Boxes here are stated in whole game pixels. *)
let box ~x ~y ~w ~h =
  Game_pixels.box { x = float x; y = float y; w = float w; h = float h }

(* The letter pages share one layout, so their edge boxes are the same. *)
let layout = function Upper | Lower -> "letters" | Others -> "others"

let edge_id page k =
  Printf.sprintf "naming.cursor.%s.r%dc%d" (layout page) k.row k.col

let edge_box page k =
  box
    ~x:(centre_x page k.col - grid.edge_dx)
    ~y:(centre_y k.row - grid.edge_dy)
    ~w:grid.edge_width ~h:grid.edge_height

let keys page =
  List.concat_map
    (fun row -> List.init (columns page) (fun col -> { row; col }))
    (List.init rows Fun.id)

let cursor_red : Color_count.range =
  { low = { r = 225; g = 0; b = 0 }; high = { r = 255; g = 150; b = 150 } }

let min_cursor_share = 0.3

let upper_blue : Color_count.range =
  { low = { r = 90; g = 140; b = 165 }; high = { r = 155; g = 205; b = 230 } }

let lower_orange : Color_count.range =
  { low = { r = 180; g = 125; b = 80 }; high = { r = 245; g = 190; b = 150 } }

let others_green : Color_count.range =
  { low = { r = 115; g = 155; b = 75 }; high = { r = 179; g = 220; b = 140 } }

let page_share = 0.8

let pages =
  [ (Upper, upper_blue); (Lower, lower_orange); (Others, others_green) ]

let page_id = function
  | Upper -> "naming.page.upper"
  | Lower -> "naming.page.lower"
  | Others -> "naming.page.others"

(* Right of the keys, and right of the entry's underscores. *)
let patch_left = 168
let page_patch_top = 96
let page_patch_width = 8
let page_patch_height = 40
let entry_patch_top = 50
let entry_patch_width = 32
let entry_patch_height = 10

let patch =
  box ~x:patch_left ~y:page_patch_top ~w:page_patch_width ~h:page_patch_height

let entry_id = "naming.entry_white"

let entry_patch =
  box ~x:patch_left ~y:entry_patch_top ~w:entry_patch_width
    ~h:entry_patch_height

let entry_white : Color_count.range =
  { low = { r = 200; g = 200; b = 200 }; high = { r = 255; g = 255; b = 255 } }

let min_entry_white = 0.9

let probes =
  Color_count.probe ~id:entry_id entry_patch entry_white
  :: List.map
       (fun (page, range) -> Color_count.probe ~id:(page_id page) patch range)
       pages
  @ List.concat_map
      (fun page ->
        List.map
          (fun k ->
            Color_count.probe ~id:(edge_id page k) (edge_box page k) cursor_red)
          (keys page))
      [ Upper; Others ]

let at_least m id share =
  match Color_count.share m id with Some s -> s >= share | None -> false

let page m =
  if not (at_least m entry_id min_entry_white) then None
  else
    match
      List.filter (fun (p, _) -> at_least m (page_id p) page_share) pages
    with
    | [ (p, _) ] -> Some p
    | _ -> None

let key page m =
  match
    List.filter
      (fun k -> at_least m (edge_id page k) min_cursor_share)
      (keys page)
  with
  | [ k ] -> Some k
  | _ -> None
