open Plza_readers
module Intro = Plza_story.New_game_intro

let probes ~picture ~home_title =
  Switch_home.Home_screen.probes ~picture Game_reload.tile_color
  @ Switch_home_tile.probes ~title:home_title
  @ Intro_screens.probes ~picture
  @ Switch_home.Keyboard_typing.probes
  @ Confirm_choices.probes ~picture

let lit_home m =
  match Switch_home.Home_screen.read m with
  | Home _ -> true
  | Home_dimmed | User_select | Elsewhere -> false

let screen_of m : Plza_story.New_game_screen.t =
  {
    home = lit_home m;
    language_entry = Intro_screens.language_entry m;
    look_picker = Intro_screens.look_picker_shown m;
    look = Intro_screens.highlighted_look m;
    name_keyboard = Intro_screens.name_keyboard_shown m;
    keyboard_cursor = Switch_home.Code_keyboard.cursor m;
    text_pixels = Switch_home.Keyboard_typing.text_pixels m;
    confirm_choices = Option.is_some (Confirm_choices.read m);
  }

let read_screen () =
  Option.fold ~none:Plza_story.New_game_screen.nothing ~some:screen_of
    (Live_story_screen.fresh ())

let ( let* ) = Result.bind

(* The fork's launch (PokemonLZA_AutoStoryLaunch.cpp): HOME (160 ms, the fork's 960 ms settings-to-HOME
   delay) to the first tile, then Right (80 ms, 500 ms released) along the
   row, PLZA's title read on a fresh frame after each, up to 8 tiles. *)
let home_walk : Switch_home.Home_title.walk =
  {
    first = { button = Home; hold_ms = 160; cooldown_ms = 960 };
    next = { button = Right; hold_ms = 80; cooldown_ms = 500 };
    tiles = 8;
  }

let title_shows () =
  Option.fold ~none:false ~some:Switch_home_tile.on_plza_tile
    (Live_story_screen.fresh ())

let find_plza_tile ~log =
  Result.map_error
    (fun e -> e ^ ": play it once so its tile moves to the front")
    (Switch_home.Home_title.find_tile
       { title_shows; press = Switch_home.Timed_press.press; log }
       home_walk ~name:"Pokémon Legends: Z-A")

let launch ~log ~picture () =
  log "AutoStory launch: closing the running game, if any.";
  let* () =
    Switch_home.Game_entry.close_game ~log ~picture Game_reload.tile_color
  in
  let* tile = find_plza_tile ~log in
  log (Printf.sprintf "AutoStory launch: launching PLZA, HOME's tile %d." tile);
  (* Slot 0: the cursor stays on PLZA's tile. *)
  Switch_home.Game_entry.start_game ~log ~picture ~game_slot:0 ~user_slot:0
    Game_reload.tile_color

let game_steps ~picture ~log : Intro.game_steps =
  {
    read_screen;
    submit = (fun cs -> ignore (Effects.submit cs : Wire.batch_done));
    launch = launch ~log ~picture;
    now = Effects.now;
    log;
  }

let run ~picture ~log ~home_title choices =
  Effects.with_probes (probes ~picture ~home_title) (fun () ->
      Intro.run (game_steps ~picture ~log) choices)
