type t = { id : string; left : int; glyph_top : int; indent : int; width : int }

let game_width = 240.
let game_height = 160.
let template_top = 1
let template_height = 12
let slack = 2
let list_row_pitch = 16
let list_first_top = 10
let summary_move_pitch = 28
let summary_first_top = 21

let bag_row i =
  {
    id = Printf.sprintf "bag.%d" i;
    left = 97;
    indent = 2;
    glyph_top = list_first_top + (list_row_pitch * i);
    width = 98;
  }

let tm_case_row i =
  {
    id = Printf.sprintf "tm_case.%d" i;
    left = 112;
    indent = 5;
    glyph_top = list_first_top + (list_row_pitch * i);
    width = 89;
  }

let summary_move i =
  {
    id = Printf.sprintf "summary_move.%d" i;
    left = 163;
    indent = 3;
    glyph_top = summary_first_top + (summary_move_pitch * i);
    width = 75;
  }

let battle_message_pitch = 16
let battle_message_first_top = 122

let battle_message i =
  {
    id = Printf.sprintf "battle_message.%d" i;
    left = 10;
    indent = 0;
    glyph_top = battle_message_first_top + (battle_message_pitch * i);
    width = 208;
  }

let box t : Wire.box =
  let x = float (t.left - t.indent - slack)
  and y = float (t.glyph_top + template_top - slack) in
  {
    x = x /. game_width;
    y = y /. game_height;
    w = float (t.width + (2 * slack)) /. game_width;
    h = float (template_height + (2 * slack)) /. game_height;
  }
