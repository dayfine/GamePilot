(* Prints the [subscribe] params of a set of FRLG reader probes, for the
   daemon's offline [probe_images] tool: the screen facts' by default, the
   menu readers' with the argument [menus]. Boxes are relative to the game
   picture, so one spec serves every backend; [probe_images --viewport] says
   where the picture sits in the images. See test_screen_readers.ml and
   test_menu_readers.ml for how the fixtures are made from it. *)

open Frlg_readers

let menu_probes =
  Start_menu.probes @ Bag_screen.probes @ Party_menu.probes
  @ Summary_screen.probes @ Money_box.probes

let () =
  let probes =
    match Sys.argv with
    | [| _; "menus" |] -> menu_probes
    | _ -> Screen_facts.probes
  in
  let call = Wire.Subscribe probes in
  let request = Wire.json_of_message (Request { id = 1; call }) in
  print_endline
    (Yojson.Safe.pretty_to_string (Yojson.Safe.Util.member "params" request))
