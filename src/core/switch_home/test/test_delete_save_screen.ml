(* The delete-save screens' reader on console B's System Settings captures
   (images/delete-save, 2026-11-25, the whole frame), and on each capture with
   its colors shifted as another capture card might show them
   (fixtures/delete_save.shifted.probes.jsonl, regen_fixture.sh), named
   <shift>/<image>: each must read as the capture itself does. Manage
   Software's page for Z-A has the same header and icon as its delete-save
   page and must not read as it. *)

open Switch_home
module S = Delete_save_screen

let fixtures = Wire.read_image_probes "delete_save.probes.jsonl"
let shifted = Wire.read_image_probes "delete_save.shifted.probes.jsonl"

let text probes =
  let m : Wire.frame = { seq = 1; t_ms = 0.; probes } in
  let games = List.filter (fun key -> S.is_game key m) [ "plza"; "firered" ] in
  String.concat ", "
    (List.concat
       [
         (if S.game_page m then [ "game page" ] else []);
         List.map (fun key -> key ^ "'s icon") games;
         [ S.caution_to_string (S.caution m) ];
         (if S.deleted m then [ "deleted" ] else []);
       ])

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

let () =
  Table_test.run "delete_save_screen"
    ([
       case "Z-A's page, Delete Save Data for the user selected"
         "za-page-delete-save-data-for-user"
         "game page, plza's icon, no red button";
       case "Manage Software's Z-A page: the icon, but not the page"
         "manage-software-za-page" "plza's icon, no red button";
       case "the list of games" "game-list-za-first" "no red button";
       case "Data Management, Delete Save Data selected"
         "data-management-delete-save-data-selected" "no red button";
       case "the user select" "user-select-native" "no red button";
       case "Caution, the red button selected" "caution-red-button-selected"
         "the red button, selected";
       case "Successfully deleted save data." "successfully-deleted"
         "no red button, deleted";
     ]
    @ shifted_cases)
