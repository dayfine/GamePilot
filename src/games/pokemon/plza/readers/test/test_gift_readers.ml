(* The Mystery Gift steps' readers (Main_menu_row, Mystery_gift_screen) on the
   PLZA captures (fixtures/gifts.probes.jsonl, regen_fixture.sh): the one
   full-size main menu (tutorial-cards' it-menu-no-card: Box highlighted, five
   Pokémon and an empty sixth card) reads its row and cards; console B's
   Internet gift list (images/mystery-gift, 2026-11-25: four gifts, the cursor
   on the first, Vivillon the 4th) reads as the active list with its gift on
   item 4; its two cards (Vivillon's, the shiny Xerneas's) read as a card;
   all also shifted (fixtures/gifts.shifted.probes.jsonl). The white fade
   before a card, the receive animation and the code keyboard read as
   nothing. The same
   list dimmed by the Switch after an idle (gift-list-dimmed, about 30%
   brightness) must read as nothing: a dim screen is no screen we know. No
   other capture reads as the menu, the list or a gift's card. The Boxes and
   the SAVE dialog (console B, 2026-11-25) read as themselves and nothing else
   does; the dialog's "Last Saved" reads the same as itself and not as a copy
   with its 18:16 made 18:18 (synthetic-..., no second save captured), in
   every shift. *)

open Plza_readers
module R = Main_menu_row
module G = Mystery_gift_screen

let frames = Wire.read_image_probes "gifts.probes.jsonl"
let shifted = Wire.read_image_probes "gifts.shifted.probes.jsonl"
let measurements probes : Wire.frame = { seq = 1; t_ms = 0.; probes }
let menu = "./tutorial-cards/it-menu-no-card.jpg"
let gift_list = "./mystery-gift/gift-list-cursor-on-1.png"

let cards m =
  String.init 6 (fun k ->
      if R.card_green m k then 'x' else if R.card_empty m k then '.' else '?')

let item = Option.fold ~none:"none" ~some:(fun k -> string_of_int (k + 1))

let list_text m =
  if G.list_active m then
    Printf.sprintf "gift list, item %s selected, the gift item %s"
      (item (G.selected_item m))
      (item (G.gift_item m))
  else "no gift list"

let text probes =
  let m = measurements probes in
  String.concat "; "
    ([
       Option.fold ~none:"no menu"
         ~some:(Printf.sprintf "menu row %d")
         (R.highlighted m);
       "cards " ^ cards m;
       list_text m;
       (if G.card m then "gift card" else "no gift card");
     ]
    @ (if Boxes_screen.shown m then [ "boxes" ] else [])
    @ if Save_dialog.shown m then [ "save dialog" ] else [])

let nothing probes =
  let m = measurements probes in
  R.highlighted m = None
  && (not (G.list_active m))
  && (not (G.card m))
  && (not (Boxes_screen.shown m))
  && not (Save_dialog.shown m)

let case name input expectation : Table_test.case = { name; input; expectation }
let menu_text = "menu row 0; cards xxxxx.; no gift list; no gift card"

let list_read =
  "no menu; cards ......; gift list, item 1 selected, the gift item 4; no gift \
   card"

let same a b = Filename.remove_extension a = Filename.remove_extension b
let card_read = "no menu; cards ......; no gift list; gift card"

let cards_shown =
  [
    "./mystery-gift/card-vivillon.png"; "./mystery-gift/card-shiny-xerneas.png";
  ]

let boxes = "./mystery-gift/boxes-xerneas-in-box-1.png"
let boxes_read = "no menu; cards ......; no gift list; no gift card; boxes"
let save_read = "no menu; cards ......; no gift list; no gift card; save dialog"

let saves =
  [
    "./mystery-gift/save-dialog-last-saved-1816.png";
    "./mystery-gift/synthetic-save-dialog-last-saved-1818.png";
  ]

let expected path =
  if same path menu then menu_text
  else if same path boxes then boxes_read
  else if List.exists (same path) saves then save_read
  else if same path gift_list then list_read
  else if List.exists (same path) cards_shown then card_read
  else "nothing"

let read probes = if nothing probes then "nothing" else text probes

(* "./bright90/mystery-gift/x.png" -> "./mystery-gift/x.png"; the shifted
   frames are png. *)
let unshifted path =
  match String.split_on_char '/' path with
  | dot :: _shift :: rest -> String.concat "/" (dot :: rest)
  | _ -> path

(* "Last Saved" 18:16 against itself and against 18:18, in one shift. *)
let shift_of path = List.nth (String.split_on_char '/' path) 1

let last_saved_cases all =
  let in_shift k =
    List.filter
      (fun (path, _) ->
        List.exists (same (unshifted path)) saves
        || List.exists (same path) saves)
      all
    |> List.filter (fun (path, _) -> shift_of path = k)
  in
  let read probes = Save_dialog.last_saved (measurements probes) in
  let compare k =
    match List.map (fun (_, p) -> read p) (in_shift k) with
    | [ Some a; Some b ] ->
        Printf.sprintf "itself %b, 18:16 and 18:18 %b"
          (Save_dialog.same_time a a)
          (Save_dialog.same_time a b)
    | _ -> "no reading"
  in
  List.map
    (fun k ->
      case
        ("Last Saved, " ^ if k = "mystery-gift" then "as captured" else k)
        (fun () -> compare k)
        "itself true, 18:16 and 18:18 false")
    (List.sort_uniq String.compare (List.map (fun (p, _) -> shift_of p) all))

let () =
  Table_test.run "gift_readers"
    (List.map
       (fun (path, probes) -> case path (fun () -> read probes) (expected path))
       frames
    @ List.map
        (fun (path, probes) ->
          case ("shifted: " ^ path)
            (fun () -> read probes)
            (expected (unshifted path)))
        shifted
    @ last_saved_cases
        (List.filter
           (fun (p, _) -> List.exists (same (unshifted p)) saves)
           shifted
        @ List.filter (fun (p, _) -> List.exists (same p) saves) frames))
