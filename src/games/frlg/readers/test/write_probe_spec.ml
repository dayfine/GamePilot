(* Prints the [subscribe] params of every FRLG screen fact probe, for the
   daemon's offline [probe_images] tool. Boxes are relative to the game
   picture, so one spec serves every backend; [probe_images --viewport] says
   where the picture sits in the images. See test_screen_readers.ml for how the
   fixtures are made from it. *)

let () =
  let call = Wire.Subscribe Frlg_readers.Screen_facts.probes in
  let request = Wire.json_of_message (Request { id = 1; call }) in
  print_endline
    (Yojson.Safe.pretty_to_string (Yojson.Safe.Util.member "params" request))
