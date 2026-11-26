type backend = Mgba | Switch
type viewport = Nso_gba | Native
type rules = Pokemon_grid | Plza_story | Plza_home | Plza_gifts

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
  group : string list;
  description : string;
  doc : string;
  checkpoints : string option;
  backends : backend list;
  viewport : viewport;
  rules : rules;
  options : Run_options.declared list;
}
