type t = {
  id : string;
  left : int;
  glyph_top : int;
  indent : int;
  width : int;
  style : Text_drawing.style;
}

let game_width = 240.
let game_height = 160.
let template_top = 1
let template_height = 12
let slack = 2

(* The list windows' dark gray text with its light gray shadow. *)
let list_text : Text_drawing.rgb = { r = 99; g = 99; b = 99 }
let list_shadow : Text_drawing.rgb = { r = 214; g = 214; b = 206 }

let bag_style : Text_drawing.style =
  {
    text = list_text;
    shadow = list_shadow;
    background = { r = 255; g = 255; b = 198 };
  }

let tm_case_style : Text_drawing.style =
  {
    text = list_text;
    shadow = list_shadow;
    background = { r = 255; g = 255; b = 189 };
  }

let summary_style : Text_drawing.style =
  {
    text = { r = 33; g = 33; b = 33 };
    shadow = { r = 222; g = 222; b = 222 };
    background = { r = 247; g = 255; b = 255 };
  }

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
    style = bag_style;
  }

let tm_case_row i =
  {
    id = Printf.sprintf "tm_case.%d" i;
    left = 112;
    indent = 5;
    glyph_top = list_first_top + (list_row_pitch * i);
    width = 89;
    style = tm_case_style;
  }

let summary_move i =
  {
    id = Printf.sprintf "summary_move.%d" i;
    left = 163;
    indent = 3;
    glyph_top = summary_first_top + (summary_move_pitch * i);
    width = 75;
    style = summary_style;
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
