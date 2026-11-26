let name_left = 65
let name_width = 98
let first_top = 10
let pitch = 16
let row_top i = first_top + (pitch * i)

let small_digit_cell id ~left ~glyph_top : Text_lines.t =
  { id; left; indent = 0; glyph_top; width = Text_lines.small_digit_width }

(* The PC's item storage (pokefirered item_pc.c): the list window 0 at tile
   (7, 1), so x 56, y 8; names at item_X 9 (x 65), rows 16 apart from y 10;
   ["×<count>"] at x 110 of the window (166), the × 8 wide. *)
let row i : Text_lines.t =
  {
    id = Printf.sprintf "item_pc.%d" i;
    left = name_left;
    indent = 2;
    glyph_top = row_top i;
    width = name_width;
  }

let count_ones_left = 184

let count_digit row k =
  small_digit_cell
    (Printf.sprintf "item_pc_count.%d.%d" row k)
    ~left:(count_ones_left - (Text_lines.small_digit_width * k))
    ~glyph_top:(row_top row)

(* The quantity window 3 at tile (24, 15), so (192, 120); ["×NNN"] at (8, 10):
   on mGBA the × inks x 201-205 and the digits' cells start at x 208, 5
   apart. *)
let quantity_left = 208
let quantity_pitch = Text_lines.small_digit_width
let quantity_top = 130

let quantity_digit k =
  small_digit_cell
    (Printf.sprintf "item_pc_quantity.%d" k)
    ~left:(quantity_left + (quantity_pitch * k))
    ~glyph_top:quantity_top

(* The player's PC's menu window is 13 tiles wide from tile 1 (pokefirered
   player_pc.c [sWindowTemplate_TopMenu_3Items]): its right frame at x 112,
   where Text_lines.pc_menu_row's 104 pixels from x 16 would reach over it. *)
let menu_width = 92

let menu_row i : Text_lines.t =
  {
    (Text_lines.pc_menu_row i) with
    id = Printf.sprintf "player_pc_menu.%d" i;
    width = menu_width;
  }
