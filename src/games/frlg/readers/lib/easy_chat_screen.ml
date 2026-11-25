type cell = { row : int; col : int }

let rows = 4
let cols = 2
let game_w = 240.
let game_h = 160.

let box ~x ~y ~w ~h : Wire.box =
  {
    x = float x /. game_w;
    y = float y /. game_h;
    w = float w /. game_w;
    h = float h /. game_h;
  }

let cells =
  List.concat_map
    (fun row -> List.init cols (fun col -> { row; col }))
    (List.init rows Fun.id)

let cell_of_index i = { row = i / cols; col = i mod cols }

(* The rectangle's left edge: x 17 or 101, inside the corners. *)
let edge_left_first = 16
let edge_left_second = 100
let edge_lefts = [| edge_left_first; edge_left_second |]
let edge_top = 90
let pitch = 16
let edge_height = 12
let edge_width = 4
let edge_id c = Printf.sprintf "easy_chat.group_edge.r%dc%d" c.row c.col

let edge_box c =
  box ~x:edge_lefts.(c.col)
    ~y:(edge_top + (pitch * c.row))
    ~w:edge_width ~h:edge_height

let red : Color_count.range =
  { low = { r = 180; g = 0; b = 0 }; high = { r = 255; g = 125; b = 125 } }

let min_red_share = 0.15

(* The arrow: x 22-27 (col 0) or 123-128 (mGBA), its rows' glyph rows. *)
let arrow_left_first = 20
let arrow_left_second = 119
let arrow_lefts = [| arrow_left_first; arrow_left_second |]
let arrow_top = 92
let arrow_width = 12
let arrow_height = 11

let arrow_box c =
  box ~x:arrow_lefts.(c.col)
    ~y:(arrow_top + (pitch * c.row))
    ~w:arrow_width ~h:arrow_height

let arrow =
  Cursor_column.make ~prefix:"easy_chat.word_arrow" (List.map arrow_box cells)

let probes =
  List.map (fun c -> Color_count.probe ~id:(edge_id c) (edge_box c) red) cells
  @ Cursor_column.probes arrow

let group_cell m =
  let red_enough c =
    match Color_count.share m (edge_id c) with
    | Some s -> s >= min_red_share
    | None -> false
  in
  match List.filter red_enough cells with [ c ] -> Some c | _ -> None

let word_cell m = Option.map cell_of_index (Cursor_column.row arrow m)
