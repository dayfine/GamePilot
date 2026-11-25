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

let start_menu_pitch = 15
let start_menu_first_top = 8

let start_menu_row i =
  {
    id = Printf.sprintf "start_menu_name.%d" i;
    left = 184;
    indent = 2;
    glyph_top = start_menu_first_top + (start_menu_pitch * i);
    width = 50;
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

(* The Pokedex count: window y 72, 16 below the money's 56. *)
let card_dex_top = 80

let trainer_card_dex_digit k =
  digit_cell "card_dex" k
    ~left:(card_ones_left - (digit_width * k))
    ~glyph_top:card_dex_top

(* The bag's message window 5 starts at (16, 120); its second line's glyphs
   at y 137 (measured on mGBA by reading the Coin Case's count). *)
let bag_message_left = 16
let bag_message_second_top = 137

let bag_message_digit k =
  digit_cell "bag_message_digit" k
    ~left:(bag_message_left + (digit_width * k))
    ~glyph_top:bag_message_second_top

(* The level in the summary's top left, on every page: "Lv" (10 wide) at x 4,
   then the digits, left-aligned (measured on mGBA). *)
let summary_level_left = 14
let summary_level_top = 18

let summary_level_digit k =
  digit_cell "summary_level" k
    ~left:(summary_level_left + (digit_width * k))
    ~glyph_top:summary_level_top

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

let mail_row_pitch = 16

let mail_field ~row ~left ~width =
  {
    id = Printf.sprintf "mail_field.r%d.x%d" row left;
    left;
    indent = 0;
    glyph_top = mail_first_row_top + (mail_row_pitch * row);
    width;
  }

(* The lower panel's list window: window 2 at tile (1, 0), its rows 16 apart
   from y 96 scrolled so the top shown row is at 92. *)
let easy_chat_list_top = 92
let easy_chat_list_pitch = 16
let easy_chat_word_left_first = 32
let easy_chat_word_left_second = 136
let easy_chat_group_left_first = 18
let easy_chat_group_left_second = 102

let easy_chat_word_lefts =
  [| easy_chat_word_left_first; easy_chat_word_left_second |]

let easy_chat_group_lefts =
  [| easy_chat_group_left_first; easy_chat_group_left_second |]

let easy_chat_rows = 4

let easy_chat_cell kind lefts ~row ~col ~width =
  {
    id = Printf.sprintf "easy_chat_%s.r%dc%d" kind row col;
    left = lefts.(col);
    indent = 0;
    glyph_top = easy_chat_list_top + (easy_chat_list_pitch * row);
    width;
  }

let easy_chat_word_cell = easy_chat_cell "word" easy_chat_word_lefts
let easy_chat_group_cell = easy_chat_cell "group" easy_chat_group_lefts

let box t : Wire.box =
  let x = float (t.left - t.indent - slack)
  and y = float (t.glyph_top + template_top - slack) in
  {
    x = x /. game_width;
    y = y /. game_height;
    w = float (t.width + (2 * slack)) /. game_width;
    h = float (template_height + (2 * slack)) /. game_height;
  }

(* The PC (pokefirered pokemon_storage_system_*.c, pc.inc's menus), measured
   on console B's captures and mGBA frames: the PC list and the storage menu
   from x 16, rows 16 apart, the capitals from y 13; a Pokémon's menu from x
   168, the capitals from y 45; PKMN DATA's window 0 at (0, 88) prints
   "/<species>" at (6, 14); the box screen's message window 1 at (88, 136)
   prints at (0, 2). *)
let pc_row_pitch = 16
let pc_menu_first_top = 10
let pc_mon_menu_first_top = 42

let pc_menu_row i =
  {
    id = Printf.sprintf "pc_menu.%d" i;
    left = 16;
    indent = 2;
    glyph_top = pc_menu_first_top + (pc_row_pitch * i);
    width = 104;
  }

let pc_mon_menu_left = 168

let pc_mon_menu_row i =
  {
    id = Printf.sprintf "pc_mon_menu.%d" i;
    left = pc_mon_menu_left;
    indent = 2;
    glyph_top = pc_mon_menu_first_top + (pc_row_pitch * i);
    width = 60;
  }

let withdraw_shift = 8

let pc_withdraw_menu_row i =
  {
    (pc_mon_menu_row i) with
    id = Printf.sprintf "pc_withdraw_menu.%d" i;
    left = pc_mon_menu_left - withdraw_shift;
    width = 68;
  }

let pc_data_species =
  { id = "pc_data_species"; left = 6; indent = 2; glyph_top = 102; width = 72 }

let pc_data_level =
  { id = "pc_data_level"; left = 34; indent = 0; glyph_top = 117; width = 24 }

let pc_message =
  { id = "pc_message"; left = 88; indent = 0; glyph_top = 138; width = 140 }

(* The Pokédex's numerical list: window at tile (2, 2), rows 14 apart from
   y 2, the names at x 56 and the No symbol at x 12, its digits 9 right. *)
let pokedex_list_rows = 9
let pokedex_list_first_top = 18
let pokedex_list_pitch = 14

let pokedex_list_row_top row =
  pokedex_list_first_top + (pokedex_list_pitch * row)

let pokedex_list_name row =
  {
    id = Printf.sprintf "pokedex_name.%d" row;
    left = 72;
    indent = 2;
    glyph_top = pokedex_list_row_top row;
    width = 62;
  }

let pokedex_number_left = 37

let pokedex_list_number_digit row k =
  small_digit_cell
    (Printf.sprintf "pokedex_number.%d.%d" row k)
    ~left:(pokedex_number_left + (small_digit_width * k))
    ~glyph_top:(pokedex_list_row_top row)
