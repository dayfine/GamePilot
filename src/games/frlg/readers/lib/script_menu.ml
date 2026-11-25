let tile = 8.

(* DrawMultichoiceMenu prints the rows and the arrow 2 pixels below the
   inside's top, 14 apart (MultichoiceList_PrintItems, Menu_InitCursor). *)
let row_offset = 2.
let row_pitch = 14.

(* The arrow fills x 145-150 and 9 rows from 2 below its row's top: its box is
   the inside's first tile across, which stops where the row's text starts. *)
let arrow_height = 12.

(* The inside's right margin, inside its last tile: no row's text reaches it. *)
let margin_inset = 6.
let margin_width = 4.

type t = { cursor : Cursor_column.t; margin_id : string; margin : Wire.box }

let tiles n = tile *. float_of_int n

let row_box ~left ~top index =
  Game_pixels.box
    {
      x = tiles left;
      y = tiles top +. row_offset +. (row_pitch *. float_of_int index);
      w = tile;
      h = arrow_height;
    }

let margin_box ~left ~top ~width ~rows =
  Game_pixels.box
    {
      x = tiles (left + width) -. margin_inset;
      y = tiles top +. 1.;
      w = margin_width;
      h = (row_pitch *. float_of_int rows) +. row_offset;
    }

let make ~prefix ~left ~top ~width ~rows =
  {
    cursor = Cursor_column.make ~prefix (List.init rows (row_box ~left ~top));
    margin_id = prefix ^ ".margin";
    margin = margin_box ~left ~top ~width ~rows;
  }

let probes t =
  (Solid_color.probe ~id:t.margin_id t.margin :: Cursor_column.probes t.cursor)
  @ Dialog.probes

(* Headroom on the Seagallop list's mGBA frames, each also shifted by
   dev/reader_fixtures/shift_frame.py (test_menu_readers.ml): the margin's
   channel sum is 690 at the least (is_white needs 500), its stddev 0 (at most
   10) and its distance from grey 0.013 at the most (0.08); the arrow's
   pixels reach 111 at the most (dark is up to 150) and the lightest pixel
   beside it 193 at the least, so its row's share stays 0.26 (0.10 needed)
   and every other row's 0. Dialog's edges sum 690 at the least (500) and its
   frame line 671 at the most (below 720). *)
let shows t m =
  Dialog.dialog_up m
  && Solid_color.holds m t.margin_id (fun s -> Solid_color.is_white s)

let cursor_row t m = if shows t m then Cursor_column.row t.cursor m else None

(* multichoice 19, 6: the inside one tile right of and below it, THREE ISLAND
   making it 11 tiles wide, moved left to end by tile 29 (the script's x plus
   the width at most 28). *)
let island_list_top = 7
let island_list_width = 11
let island_list_right = 29
let island_list_rows = 3

let seagallop_islands =
  make ~prefix:"seagallop_islands"
    ~left:(island_list_right - island_list_width)
    ~top:island_list_top ~width:island_list_width ~rows:island_list_rows
