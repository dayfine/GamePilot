(* The HOME reader on console B's captures (images/, 2026-11-24 and 25), and
   on each capture with its colors shifted as another capture card might show
   them (fixtures/switch.shifted.probes.jsonl, regen_fixture.sh: brightness
   times 0.9 and 1.1, one channel plus or minus 12, 10% toward mid-grey),
   named <shift>/<image>: each must read as the capture itself does. *)

open Switch_home

let fixtures = Wire.read_image_probes "switch.probes.jsonl"
let shifted = Wire.read_image_probes "switch.shifted.probes.jsonl"

let text probes =
  let m : Wire.frame = { seq = 1; t_ms = 0.; probes } in
  String.concat ""
    [
      Home_screen.to_string (Home_screen.read m);
      (if Home_screen.black m then ", black" else "");
      (if Close_game_popup.shown m then ", the close-game popup" else "");
      (if Black_screen.shown m then ", the launch's black" else "");
    ]

let read name () = text (List.assoc ("./" ^ name ^ ".png") fixtures)

(* "./<shift>/<image>" to "./<image>". *)
let unshifted image =
  match String.split_on_char '/' image with
  | [ "."; _; file ] -> "./" ^ file
  | _ -> failwith ("no shift in " ^ image)

let shifted_cases =
  List.map
    (fun (image, probes) : Table_test.case ->
      {
        name = "shifted: " ^ image;
        input = (fun () -> text probes);
        expectation = text (List.assoc (unshifted image) fixtures);
      })
    shifted

let case name input expectation : Table_test.case =
  { name; input = read input; expectation }

(* A probe's box on a viewport, or "none" when it is not probed. *)
let box_on picture id () =
  match
    List.find_opt
      (fun (p : Wire.probe_spec) -> p.id = id)
      (Home_screen.probes ~picture Fire_red.tile)
  with
  | None -> "none"
  | Some p -> Printf.sprintf "%g %g %g %g" p.box.x p.box.y p.box.w p.box.h

let native : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. }

let viewport_cases : Table_test.case list =
  [
    {
      name = "native viewport: the fork's box, unchanged";
      input = box_on native "home.top";
      expectation = "0.510223 0.019835 0.44145 0.034711";
    };
    {
      name = "native viewport: the user icons read";
      input = box_on native "home.user_icons";
      expectation = "0.05 0.05 0.2 0.08";
    };
    {
      name = "GBA viewport: a box partly outside the picture, clipped";
      input = box_on Fire_red.nso_gba_picture "home.game_slot";
      expectation = "0 0.254808 0.106154 0.394615";
    };
    {
      name = "GBA viewport: the user icons, cut by the picture, left out";
      input = box_on Fire_red.nso_gba_picture "home.user_icons";
      expectation = "none";
    };
  ]

let () =
  Table_test.run "home_screen"
    ([
       case "HOME, BDSP played last and the cursor on it"
         "home-cursor-on-last-played"
         "HOME (cursor on tile 0, the game's tile 1)";
       case "HOME, the cursor moved onto FireRed" "home-cursor-on-firered"
         "HOME (cursor on tile 1, the game's tile 1)";
       case "HOME scrolled, a part tile at the left, the cursor on FireRed"
         "home-scrolled-part-tile-left-cursor-on-firered"
         "HOME (cursor on tile 0, the game's tile 0)";
       case "HOME scrolled, the cursor on Legends Z-A, FireRed out of view"
         "home-scrolled-cursor-on-legends-za-firered-out-of-view"
         "HOME (cursor on tile 1, the game's tile none)";
       case "the cursor at its pulse's brightest (red lost it before)"
         "home-scrolled-cursor-pulse-brightest"
         "HOME (cursor on tile 1, the game's tile none)";
       case "the cursor on the fourth tile in view"
         "home-scrolled-cursor-on-fourth-tile"
         "HOME (cursor on tile 3, the game's tile none)";
       case "the cursor on the eShop button, off the row"
         "home-cursor-on-eshop-button"
         "HOME (cursor on tile none, the game's tile none)";
       case "HOME dimmed after a while untouched" "home-dimmed"
         "HOME, dimmed (tiles not read)";
       case "the user select over a dimmed HOME" "user-select" "the user select";
       case "the Game Freak intro after a launch" "launch-game-freak-intro"
         "not HOME";
       case "FireRed's load menu" "firered-load-menu" "not HOME";
       case "X on FireRed's tile: the close-software popup"
         "home-close-software-popup" "not HOME, the close-game popup";
     ]
    @ shifted_cases @ viewport_cases)
