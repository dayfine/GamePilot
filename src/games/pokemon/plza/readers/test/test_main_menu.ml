(* The main menu (PokemonLZA_MainMenuDetector.cpp): its right arrow and its B
   button both show. The one full-size menu frame (tutorial-cards'
   it-menu-no-card) reads it: right arrow 9.9 (bound 70), B 17.3 (bound 80).
   B alone shows on Confirm Choices, a blue text box and the map, which do not
   read as the menu; nothing else shows the right arrow (the nearest blob,
   the minimap's corner, scores 93.5 at least).

   01.02's run frames of the menu (640x360 scaled up, console B, 2026-11-25:
   the early menu, Satchel alone) do not read it: no right arrow blob, and B
   scores 92.7, blurred past its bound. A full-size console frame of 03.15's
   menu is wanted. Every frame shifted reads as unshifted. *)

open Plza_readers

let yes = Fixture_frames.yes_no

let read m =
  let right, b = Main_menu.buttons m in
  Printf.sprintf "menu %s (right %s, B %s)"
    (yes (Main_menu.shown m))
    (yes right) (yes b)

let menu_frames = [ "tutorial-cards/it-menu-no-card" ]

let b_alone =
  [
    "confirm-choices/English_0";
    "confirm-choices/English_1";
    "confirm-choices/English_2";
    "confirm-choices/German_2";
    "confirm-choices/Japanese_1";
    "dialog-boxes/mac-cannot-fast-travel-blue-box";
    "map-pin/zone1-at-north-fence";
    "map-pin/zone1-stop-10-under-badge";
  ]

let expected name =
  if List.mem name menu_frames then "menu yes (right yes, B yes)"
  else if List.mem name b_alone then "menu no (right no, B yes)"
  else "menu no (right no, B no)"

let cases =
  List.map
    (fun (path, _) ->
      let name = Fixture_frames.frame_name path in
      {
        Table_test.name;
        input = (fun () -> read (Fixture_frames.frame name));
        expectation = expected name;
      })
    Fixture_frames.frames

let () =
  Table_test.run "main_menu"
    (cases @ Fixture_frames.shifted_cases ~misses:true read)
