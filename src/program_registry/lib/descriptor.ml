type backend = Mgba | Switch
type viewport = Nso_gba | Native
type rules = Pokemon_grid | Plza_story | Pokemon_home | Plza_gifts

type category =
  | Testing
  | Story
  | Glitch_setup
  | Farming
  | Dex_collection
  | Shiny_hunting
  | Gifts
  | Storage

type switch_home = {
  title : string;
  home_tile : Switch_home.Home_screen.tile_color;
  lab_panel : string;
}

type game = {
  game_id : string;
  game_name : string;
  delete_save_icons : (string * string) list;
  switch_home : switch_home option;
}

type t = {
  id : string;
  game : game;
  name : string;
  category : category;
  description : string;
  doc : string;
  checkpoints : string option;
  backends : backend list;
  viewport : viewport;
  rules : rules;
  options : Run_options.declared list;
}

let category_name = function
  | Testing -> "Testing"
  | Story -> "Story"
  | Glitch_setup -> "Glitch Setup"
  | Farming -> "Farming"
  | Dex_collection -> "Dex Collection"
  | Shiny_hunting -> "Shiny Hunting"
  | Gifts -> "Gifts"
  | Storage -> "Storage"
