(* Prints the [subscribe] params for the daemon's offline [probe_images] tool
   (regen_fixture.sh): every Pokémon HOME reader's probes on the whole frame,
   the templates named by the files beside the spec (the assets' names), the
   cursor arrow's probes over the slots the steps read it on. *)

open Pokemon_home

let digits = List.init 10 Fun.id

let templates : Box_view.templates =
  {
    slash = "box-counter-slash-300.png";
    digits = List.map (fun d -> (d, Printf.sprintf "box-digit-%d.png" d)) digits;
  }

let cursor_slots : Box_view.slot list =
  [
    { pane = Home_box; row = 0; col = 0 };
    { pane = Home_box; row = 0; col = 1 };
    { pane = Home_box; row = 3; col = 5 };
    { pane = Home_box; row = 2; col = 5 };
    { pane = Game_box; row = 0; col = 0 };
    { pane = Game_box; row = 0; col = 1 };
  ]

let () =
  let probes =
    Home_menus.probes ~game_icon:"home-game-icon.png"
    @ Home_tile.probes ~art:"switch-home-tile.png"
        ~title:"switch-home-title-pokemon-home.png"
    @ Box_view.probes templates
    @ List.concat_map Box_view.cursor_probes cursor_slots
  in
  let request =
    Wire.json_of_message (Request { id = 1; call = Subscribe probes })
  in
  print_endline
    (Yojson.Safe.pretty_to_string (Yojson.Safe.Util.member "params" request))
