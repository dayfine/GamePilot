(* Pokémon HOME's readers (Home_menus, Home_tile, Box_view) on console B's
   captures (images/, 2026-11-24 and the Switch's HOME after PLZA's gifts of
   2026-11-25, the whole frame), and on each capture with
   its colors shifted as another capture card might show them
   (fixtures/home.shifted.probes.jsonl, regen_fixture.sh), named
   <shift>/<image>: each must read as the capture itself does. *)

open Pokemon_home
module B = Box_view

let fixtures = Wire.read_image_probes "home.probes.jsonl"
let shifted = Wire.read_image_probes "home.shifted.probes.jsonl"
let frame probes : Wire.frame = { seq = 1; t_ms = 0.; probes }
let tile_text (t : Home_menus.tile) = Printf.sprintf "(%d, %d)" t.row t.col

let menus m =
  List.concat
    [
      (if Home_menus.main_menu m then [ "main menu" ] else []);
      (match Home_menus.banner m with
      | No_banner -> []
      | b -> [ Home_menus.banner_to_string b ]);
      Option.fold ~none:[]
        ~some:(fun t -> [ "game list, cursor " ^ tile_text t ])
        (Home_menus.cursor_tile m);
      Option.fold ~none:[]
        ~some:(fun t -> [ "the game's icon " ^ tile_text t ])
        (Home_menus.game_tile m);
      Option.fold ~none:[]
        ~some:(fun k -> [ Printf.sprintf "HOME's tile %d" k ])
        (Home_tile.tile m);
      (if Home_tile.on_home_tile m then [ "the cursor on HOME's tile" ] else []);
    ]

let slot pane row col : B.slot = { pane; row; col }

let pane_text m pane =
  String.concat "/"
    (List.init B.slot_rows (fun row ->
         String.init B.columns (fun col ->
             if B.empty m (slot pane row col) then '.' else 'x')))

let cursors =
  [ slot Home_box 0 0; slot Home_box 3 5; slot Game_box 0 0; slot Game_box 0 1 ]

let boxes m =
  if not (B.shown m) then []
  else
    [
      "box " ^ Option.fold ~none:"unread" ~some:string_of_int (B.number m);
      "home " ^ pane_text m Home_box;
      "game row 1 " ^ String.sub (pane_text m Game_box) 0 B.columns;
      "cursor "
      ^ String.concat " "
          (List.map B.slot_to_string (List.filter (B.cursor_at m) cursors));
    ]

let text probes =
  let m = frame probes in
  match menus m @ boxes m with
  | [] -> "nothing"
  | parts -> String.concat "; " parts

let read name () = text (List.assoc ("./" ^ name ^ ".png") fixtures)

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

let () =
  Table_test.run "home_readers"
    ([
       case "the main menu" "main-menu" "main menu";
       case "the main menu after saving" "main-menu-after-save" "main menu";
       case "logging in" "logging-in" "a two-line banner";
       case "the login banner, blank" "loading-blank-banner" "a blank banner";
       case "the game list, cursor on BDSP, Z-A beside it"
         "game-select-cursor-on-bdsp"
         "game list, cursor (1, 0); the game's icon (1, 1)";
       case "box 152 before banking, cursor on HOME's first slot"
         "boxes-152-before-bank-cursor-0-0"
         "box 152; home xxxx../xxxxxx/xxxxxx/xxx.../xxx...; game row 1 xxx...; \
          cursor HOME's box row 1 column 1";
       case "box 152 after banking: three more in HOME's, the game's emptied"
         "boxes-152-after-bank"
         "box 152; home xxxx../xxxxxx/xxxxxx/xxxxxx/xxx...; game row 1 ......; \
          cursor HOME's box row 4 column 6";
       case "saving: its two lines over the boxes" "boxes-saving"
         "a two-line banner; box 152; home xxxx../xxxxxx/xxxxxx/xxxxxx/xxx...; \
          game row 1 ......; cursor HOME's box row 4 column 6";
       case "the Switch's HOME, cursor on Pokémon HOME"
         "switch-home-cursor-on-pokemon-home"
         "HOME's tile 0; the cursor on HOME's tile";
       case "the Switch's HOME, Pokémon HOME third"
         "switch-home-pokemon-home-third" "HOME's tile 2";
       case "the Switch's HOME after PLZA closed: HOME the fifth, cut off"
         "switch-home-cursor-on-za-home-fifth-cut" "nothing";
     ]
    @ shifted_cases)
