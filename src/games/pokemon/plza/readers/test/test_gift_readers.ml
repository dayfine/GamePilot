(* The Mystery Gift steps' readers (Main_menu_row, Mystery_gift_screen) on the
   PLZA captures (fixtures/gifts.probes.jsonl, regen_fixture.sh): the one
   full-size main menu (tutorial-cards' it-menu-no-card: Box highlighted, five
   Pokémon and an empty sixth card) reads its row and cards; console B's
   Internet gift list (images/mystery-gift, 2026-11-25: four gifts, the cursor
   on the first, Vivillon the 4th) reads as the active list with its gift on
   item 4; both also shifted (fixtures/gifts.shifted.probes.jsonl). The same
   list dimmed by the Switch after an idle (gift-list-dimmed, about 30%
   brightness) must read as nothing: a dim screen is no screen we know. No
   other capture reads as the menu, the list or a gift's card. No capture of a card
   exists, so nothing reads one positively yet. *)

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
    [
      Option.fold ~none:"no menu"
        ~some:(Printf.sprintf "menu row %d")
        (R.highlighted m);
      "cards " ^ cards m;
      list_text m;
      (if G.card m then "gift card" else "no gift card");
    ]

let nothing probes =
  let m = measurements probes in
  R.highlighted m = None && (not (G.list_active m)) && not (G.card m)

let case name input expectation : Table_test.case = { name; input; expectation }
let menu_text = "menu row 0; cards xxxxx.; no gift list; no gift card"

let list_read =
  "no menu; cards ......; gift list, item 1 selected, the gift item 4; no gift \
   card"

let same a b = Filename.remove_extension a = Filename.remove_extension b

let expected path =
  if same path menu then menu_text
  else if same path gift_list then list_read
  else "nothing"

let read probes = if nothing probes then "nothing" else text probes

(* "./bright90/mystery-gift/x.png" -> "./mystery-gift/x.png"; the shifted
   frames are png. *)
let unshifted path =
  match String.split_on_char '/' path with
  | dot :: _shift :: rest -> String.concat "/" (dot :: rest)
  | _ -> path

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
        shifted)
