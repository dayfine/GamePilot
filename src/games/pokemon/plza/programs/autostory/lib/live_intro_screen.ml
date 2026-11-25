open Plza_readers
module Intro = Plza_story.New_game_intro

let probes ~picture =
  Switch_home.Home_screen.probes ~picture Game_reload.tile_color
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

(* launch_plza_from_home, with PLZA's tile the first. *)
let launch ~log ~picture () =
  log "AutoStory launch: closing the running game, if any.";
  let* () =
    Switch_home.Game_entry.close_game ~log ~picture Game_reload.tile_color
  in
  log "AutoStory launch: launching PLZA, HOME's first tile.";
  Switch_home.Game_entry.start_game ~log ~picture ~game_slot:1 ~user_slot:0
    Game_reload.tile_color

let game_steps ~picture ~log : Intro.game_steps =
  {
    read_screen;
    submit = (fun cs -> ignore (Effects.submit cs : Wire.batch_done));
    launch = launch ~log ~picture;
    now = Effects.now;
    log;
  }

let run ~picture ~log choices =
  Effects.with_probes (probes ~picture) (fun () ->
      Intro.run (game_steps ~picture ~log) choices)
