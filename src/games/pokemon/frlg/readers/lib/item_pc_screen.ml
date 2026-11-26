let box ~x ~y ~w ~h =
  Game_pixels.box { x = float x; y = float y; w = float w; h = float h }

let label_id = "item_pc.label"

(* Window 2 at tile (1, 1), 5 by 4 tiles: its top 32 by 32. *)
let label_corner = 8
let label_size = 32
let label_box = box ~x:label_corner ~y:label_corner ~w:label_size ~h:label_size

let label_orange : Color_count.range =
  { low = { r = 200; g = 100; b = 0 }; high = { r = 255; g = 165; b = 80 } }

let min_label_share = 0.4
let quantity_id = "item_pc.quantity"

(* The quantity box's up arrow, x 205-215, bobbing over y 114-124. *)
let arrow_box_left = 204
let arrow_box_top = 114
let arrow_box_width = 14
let arrow_box_height = 11

let quantity_box =
  box ~x:arrow_box_left ~y:arrow_box_top ~w:arrow_box_width ~h:arrow_box_height

let arrow_orange : Color_count.range =
  { low = { r = 220; g = 40; b = 0 }; high = { r = 255; g = 130; b = 60 } }

let min_quantity_arrow = 0.12
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

let cursor =
  Cursor_column.make ~prefix:"item_pc.cursor" (List.init rows row_box)

let probes =
  Cursor_column.probes cursor
  @ [
      Color_count.probe ~id:label_id label_box label_orange;
      Color_count.probe ~id:quantity_id quantity_box arrow_orange;
    ]

let shown m =
  Option.map (fun s -> s >= min_label_share) (Color_count.share m label_id)

let cursor_row m = Cursor_column.row cursor m

let quantity_shown m =
  Option.map
    (fun s -> s >= min_quantity_arrow)
    (Color_count.share m quantity_id)
