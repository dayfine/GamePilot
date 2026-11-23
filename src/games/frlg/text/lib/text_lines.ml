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

(* The info page's right pane (window left 15 tiles, top 2) prints the species
   at (47, 19). *)
let summary_species =
  { id = "summary_species"; left = 167; indent = 2; glyph_top = 35; width = 72 }

let digit_width = 6

let digit_cell id k ~left ~glyph_top =
  {
    id = Printf.sprintf "%s.%d" id k;
    left;
    indent = 0;
    glyph_top;
    width = digit_width;
  }

(* The card's window starts at (8, 8); the money string (the yen sign, 8 wide,
   then the digits) ends at x 136 of the window, the ones digit from 130. *)
let card_ones_left = 138
let card_money_top = 64

let trainer_card_money_digit k =
  digit_cell "card_money" k
    ~left:(card_ones_left - (digit_width * k))
    ~glyph_top:card_money_top

(* The bag's message window 5 starts at (16, 120); its second line's glyphs
   at y 137 (measured on mGBA by reading the Coin Case's count). *)
let bag_message_left = 16
let bag_message_second_top = 137

let bag_message_digit k =
  digit_cell "bag_message_digit" k
    ~left:(bag_message_left + (digit_width * k))
    ~glyph_top:bag_message_second_top

let small_digit_width = 5

let small_digit_cell id ~left ~glyph_top =
  { id; left; indent = 0; glyph_top; width = small_digit_width }

let list_row_top row = list_first_top + (list_row_pitch * row)

(* The list window starts at x 88; the count prints at x 110 as "×" (8 wide)
   and three digit cells. *)
let count_ones_left = 216

let bag_count_digit row k =
  small_digit_cell
    (Printf.sprintf "bag_count.%d.%d" row k)
    ~left:(count_ones_left - (small_digit_width * k))
    ~glyph_top:(list_row_top row)

(* The label at x 97: the No symbol (8 wide), CLEAR 1, then the digits. *)
let berry_number_left = 106

let berry_pouch_number_digit row k =
  small_digit_cell
    (Printf.sprintf "pouch_number.%d.%d" row k)
    ~left:(berry_number_left + (small_digit_width * k))
    ~glyph_top:(list_row_top row)

(* The phrase window at x 24; a row's first word after CLEAR 17. *)
let mail_field_one_left = 41
let mail_first_row_top = 2

let mail_field_one ~width =
  {
    id = "mail_field.1";
    left = mail_field_one_left;
    indent = 0;
    glyph_top = mail_first_row_top;
    width;
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
