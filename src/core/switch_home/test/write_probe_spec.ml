(* Prints the [subscribe] params of the HOME reader's probes, with FireRed's
   tile colour, for the daemon's offline [probe_images] tool
   (regen_fixture.sh). *)

let () =
  let call =
    Wire.Subscribe (Switch_home.Home_screen.probes Fire_red_spec.tile)
  in
  let request = Wire.json_of_message (Request { id = 1; call }) in
  print_endline
    (Yojson.Safe.pretty_to_string (Yojson.Safe.Util.member "params" request))
