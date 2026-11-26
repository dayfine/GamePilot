(* Prints the [subscribe] params of a set of FRLG reader probes, for the
   daemon's offline [probe_images] tool: the screen facts' by default, the
   menu readers' with the argument [menus], the battle prompts' with
   [battle], the PC's with [pc], the Trainer Card's with [card], the ACE setup's (Easy Chat, box
   screen) with [ace], the Pokédex's with [dex], the naming screen's (and the box
   title menu's) with [naming]. Boxes are relative to the game
   picture, so one spec serves every backend; [probe_images --viewport] says
   where the picture sits in the images. regen_fixtures.sh makes the fixtures
   with it. *)

open Frlg_readers

let menu_probes =
  Start_menu.probes @ Bag_screen.probes @ Party_menu.probes
  @ Summary_screen.probes @ Money_box.probes @ Move_list_cursor.probes
  @ Member_menu.probes @ Berry_pouch_screen.probes @ Mail_editor.probes
  @ Party_dialogs.probes @ Shiny_star.probes
  @ Script_menu.probes Script_menu.seagallop_islands

let battle_probes =
  Battle_screen.probes @ Battle_yes_no.probes @ Battle_text_arrow.probes
  @ Move_pp.probes @ Dark_corners.probes @ Caught_mark.probes

let () =
  let probes =
    match Sys.argv with
    | [| _; "menus" |] -> menu_probes
    | [| _; "battle" |] -> battle_probes
    | [| _; "pc" |] -> Pc_screen.probes
    | [| _; "card" |] -> Trainer_card_front.probes
    | [| _; "ace" |] -> Easy_chat_screen.probes @ Pc_box_screen.probes
    | [| _; "dex" |] -> Pokedex_list.probes
    | [| _; "naming" |] -> Naming_screen.probes @ Pc_box_screen.probes
    | [| _; "trigger" |] ->
        Pc_box_screen.probes @ Item_pc_screen.probes @ Pc_screen.probes
    | _ ->
        Screen_facts.probes @ Scene_signature.probes @ Dialog.yes_no_probes
        @ Load_menu.probes
  in
  let call = Wire.Subscribe probes in
  let request = Wire.json_of_message (Request { id = 1; call }) in
  print_endline
    (Yojson.Safe.pretty_to_string (Yojson.Safe.Util.member "params" request))
