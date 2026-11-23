(* Prints the [subscribe] params of every FRLG screen fact probe, for the
   daemon's offline [probe_images] tool. One argument: the backend whose frames
   the images are, [mgba] or [switch]. See test_screen_readers.ml for how the
   fixtures are made from it. *)

let () =
  let screen =
    match Sys.argv with
    | [| _; "mgba" |] -> Frlg_readers.Game_screen.whole_frame
    | [| _; "switch" |] -> Frlg_readers.Game_screen.switch_capture
    | _ -> failwith "usage: write_probe_spec.exe mgba|switch"
  in
  let call = Wire.Subscribe (Frlg_readers.Screen_facts.probes screen) in
  let request = Wire.json_of_message (Request { id = 1; call }) in
  print_endline
    (Yojson.Safe.pretty_to_string (Yojson.Safe.Util.member "params" request))
