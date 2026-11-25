(* Prints the [subscribe] params for the daemon's offline [probe_images] tool
   (regen_fixture.sh). With no argument: the HOME, close-game popup and launch
   black readers' probes, with FireRed's tile colour, on the GBA picture. With
   [delete-save]: the delete-save screens' probes on the whole frame, an icon
   probe per game whose template is the PNG file [<key>-icon.png] beside the
   spec. *)

let home_probes () =
  let picture = Fire_red_spec.nso_gba_picture in
  Switch_home.Home_screen.probes ~picture Fire_red_spec.tile
  @ Switch_home.Close_game_popup.probes ~picture
  @ Switch_home.Black_screen.probes ~picture

let delete_save_probes () =
  let module S = Switch_home.Delete_save_screen in
  List.map
    (fun key -> S.icon_probe { key; icon = key ^ "-icon.png" })
    [ "plza"; "firered" ]
  @ S.colour_probes

let () =
  let probes =
    match Sys.argv with
    | [| _; "delete-save" |] -> delete_save_probes ()
    | _ -> home_probes ()
  in
  let request =
    Wire.json_of_message (Request { id = 1; call = Subscribe probes })
  in
  print_endline
    (Yojson.Safe.pretty_to_string (Yojson.Safe.Util.member "params" request))
