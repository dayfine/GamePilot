let box ~x ~y ~w ~h =
  Game_pixels.box { x = float x; y = float y; w = float w; h = float h }

let label_id = "item_pc.label"
let label_box = box ~x:8 ~y:8 ~w:32 ~h:32

let label_orange : Color_count.range =
  { low = { r = 200; g = 100; b = 0 }; high = { r = 255; g = 165; b = 80 } }

let min_label_share = 0.4
let quantity_id = "item_pc.quantity"
let quantity_box = box ~x:194 ~y:124 ~w:36 ~h:24

let white : Color_count.range =
  { low = { r = 240; g = 240; b = 240 }; high = { r = 255; g = 255; b = 255 } }

let min_quantity_white = 0.5
let rows = 6

(* The arrow: x 58-62 inked, y 12-20 on row 0. *)
let arrow_left = 57
let arrow_width = 7
let arrow_first_top = 11
let arrow_height = 11
let row_pitch = 16

let row_box i =
  box ~x:arrow_left
    ~y:(arrow_first_top + (row_pitch * i))
    ~w:arrow_width ~h:arrow_height

let cursor = Cursor_column.make ~prefix:"item_pc.cursor" (List.init rows row_box)

let probes =
  Cursor_column.probes cursor
  @ [
      Color_count.probe ~id:label_id label_box label_orange;
      Color_count.probe ~id:quantity_id quantity_box white;
    ]

let shown m =
  Option.map (fun s -> s >= min_label_share) (Color_count.share m label_id)

let cursor_row m = Cursor_column.row cursor m

let quantity_shown m =
  Option.map
    (fun s -> s >= min_quantity_white)
    (Color_count.share m quantity_id)
