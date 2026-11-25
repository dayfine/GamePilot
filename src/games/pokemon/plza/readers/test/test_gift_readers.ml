(* The Mystery Gift steps' readers (Main_menu_row, Mystery_gift_screen) on the
   PLZA captures (fixtures/gifts.probes.jsonl, regen_fixture.sh): the one
   full-size main menu (tutorial-cards' it-menu-no-card: Box highlighted, five
   Pokémon and an empty sixth card) reads its row and cards, also shifted
   (fixtures/gifts.shifted.probes.jsonl); no other capture reads as the menu
   or a gift's card. A white fade and two white text boxes read as the gift
   list (a white top bar, no blue box): the steps take the list only once it
   has held 1 s. No capture of the Mystery Gift screens exists, so nothing
   reads them positively yet. *)

open Plza_readers
module R = Main_menu_row

let frames = Wire.read_image_probes "gifts.probes.jsonl"
let shifted = Wire.read_image_probes "gifts.shifted.probes.jsonl"
let measurements probes : Wire.frame = { seq = 1; t_ms = 0.; probes }
let menu = "./tutorial-cards/it-menu-no-card.jpg"

let cards m =
  String.init 6 (fun k ->
      if R.card_green m k then 'x' else if R.card_empty m k then '.' else '?')

let text probes =
  let m = measurements probes in
  String.concat "; "
    [
      Option.fold ~none:"no menu"
        ~some:(Printf.sprintf "menu row %d")
        (R.highlighted m);
      "cards " ^ cards m;
      (if Mystery_gift_screen.list_active m then "gift list" else "no gift list");
      (if Mystery_gift_screen.card m then "gift card" else "no gift card");
    ]

let not_menu probes =
  let m = measurements probes in
  R.highlighted m = None
  && (not (Mystery_gift_screen.list_active m))
  && not (Mystery_gift_screen.card m)

let case name input expectation : Table_test.case = { name; input; expectation }

let white_as_list =
  [
    "./arrival-past-mission-banner/0008-white-fade.jpg";
    "./arrival-past-mission-banner/0015-text-box.jpg";
    "./arrival-to-ad/0013-text-box.jpg";
  ]

let others =
  List.map
    (fun (path, probes) ->
      case path
        (fun () -> if not_menu probes then "nothing" else text probes)
        (if List.mem path white_as_list then
           "no menu; cards ......; gift list; no gift card"
         else "nothing"))
    (List.filter (fun (path, _) -> path <> menu) frames)

let menu_text = "menu row 0; cards xxxxx.; no gift list; no gift card"

let () =
  Table_test.run "gift_readers"
    (case "the main menu, Box highlighted, five in the party"
       (fun () -> text (List.assoc menu frames))
       menu_text
     :: List.map
          (fun (path, probes) ->
            case ("shifted: " ^ path) (fun () -> text probes) menu_text)
          shifted
    @ others)
