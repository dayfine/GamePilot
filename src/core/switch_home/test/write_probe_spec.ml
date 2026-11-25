(* Prints the [subscribe] params of the HOME, close-game popup and launch
   black readers' probes, with FireRed's tile colour, for the daemon's offline [probe_images] tool
   (regen_fixture.sh). *)

let () =
  let call =
    let picture = Fire_red_spec.nso_gba_picture in
    Wire.Subscribe
      (Switch_home.Home_screen.probes ~picture Fire_red_spec.tile
      @ Switch_home.Close_game_popup.probes ~picture
      @ Switch_home.Black_screen.probes ~picture)
  in
  let request = Wire.json_of_message (Request { id = 1; call }) in
  print_endline
    (Yojson.Safe.pretty_to_string (Yojson.Safe.Util.member "params" request))
