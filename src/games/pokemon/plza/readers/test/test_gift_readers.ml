(* The Mystery Gift steps' readers (Main_menu_row, Mystery_gift_screen) on the
   PLZA captures (fixtures/gifts/gifts.probes.jsonl, regen_fixture.sh): the one
   full-size main menu (tutorial-cards' it-menu-no-card: Box highlighted, five
   Pokémon and an empty sixth card) reads its row and cards; console B's
   Internet gift list (images/mystery-gift, 2026-11-25: four gifts, the cursor
   on the first, Vivillon the 4th) reads as the active list with its gift on
   item 4; Vivillon's card reads as a card;
   all also shifted (fixtures/gifts/gifts.shifted.probes.jsonl). The French list
   (console B, 2026-11-25: the same four gifts, Vivillon the 4th as
   "Prismillon (Motif Poké Ball)") reads as the list with no gift under the
   English name, as the console's run failed; under the French name
   (fixtures/gifts/gifts.fr.probes.jsonl, every Mystery Gift frame and its nine
   shifts) its gift is item 4 and the English list has none. The white fade
   before a card reads as nothing. The same
   list dimmed by the Switch after an idle (gift-list-dimmed, about 30%
   brightness) must read as nothing: a dim screen is no screen we know. No
   other capture reads as the menu, the list or a gift's card. The Boxes and
   the SAVE dialog (console B, 2026-11-25) read as themselves and nothing else
   does; on the Boxes (console B's, Xerneas under the cursor, and the fork's
   box-cells captures) the cursor's cell reads as holding a Pokémon or empty,
   a Pokémon held over an empty cell empty; the dialog's "Last Saved" reads the same as itself and not as a copy
   with its 18:16 made 18:18 (synthetic-..., no second save captured), in
   every shift. So does a copy with its date and time where the French game
   shows them (synthetic-save-dialog-fr-layout-..., console B, 2026-11-25:
   no French frame was captured; placed where that run's reading of the old
   time box shows them), whose old box read only the date. Every capture is
   redacted to what its reader probes (images/mystery-gift/README.md,
   images/switch/box-cells/README.md). *)

open Plza_readers
module R = Main_menu_row
module G = Mystery_gift_screen

let frames = Wire.read_image_probes "fixtures/gifts/gifts.probes.jsonl"
let shifted = Wire.read_image_probes "fixtures/gifts/gifts.shifted.probes.jsonl"
let french = Wire.read_image_probes "fixtures/gifts/gifts.fr.probes.jsonl"
let measurements probes : Wire.frame = { seq = 1; t_ms = 0.; probes }
let menu = "./tutorial-cards/it-menu-no-card.jpg"
let gift_list = "./mystery-gift/gift-list-cursor-on-1.png"
let french_list = "./mystery-gift/gift-list-fr-cursor-on-1.png"

let cards m =
  String.init 6 (fun k ->
      if R.card_green m k then 'x' else if R.card_empty m k then '.' else '?')

let item = Option.fold ~none:"none" ~some:(fun k -> string_of_int (k + 1))
let case name input expectation : Table_test.case = { name; input; expectation }

(* Each reader's text for a frame, one reader per case. *)
let menu_text m =
  Option.fold ~none:"no menu"
    ~some:(fun r -> Printf.sprintf "menu row %d; cards %s" r (cards m))
    (R.highlighted m)

let list_text m =
  if G.list_active m then
    Printf.sprintf "gift list, item %s selected, the gift item %s"
      (item (G.selected_item m))
      (item (G.gift_item m))
  else "no gift list"

let card_text m = if G.card m then "gift card" else "no gift card"

let boxes_text m =
  if not (Boxes_screen.shown m) then "no boxes"
  else if Box_cell.holds_pokemon m then "boxes, a Pokémon in the cell"
  else "boxes, an empty cell"

let save_text m =
  if Save_dialog.shown m then "save dialog" else "no save dialog"

let same a b = Filename.remove_extension a = Filename.remove_extension b
let cards_shown = [ "./mystery-gift/card-vivillon.png" ]
let boxes = "./mystery-gift/boxes-xerneas-in-box-1.png"

(* The fork's captures of the Boxes (box-cells/: CommandLineTests'
   BoxCellInfoDetector frames at 360p), named by what the cursor is on. *)
let box_cell path =
  match String.split_on_char '/' path with
  | [ _; "box-cells"; frame ] ->
      Some (String.starts_with ~prefix:"pokemon" frame)
  | _ -> None

(* Each "Last Saved" layout's 18:16 and 18:18. *)
let save_pairs =
  [
    ( "English",
      "./mystery-gift/save-dialog-last-saved-1816.png",
      "./mystery-gift/synthetic-save-dialog-last-saved-1818.png" );
    ( "French layout",
      "./mystery-gift/synthetic-save-dialog-fr-layout-1816.png",
      "./mystery-gift/synthetic-save-dialog-fr-layout-1818.png" );
  ]

let saves = List.concat_map (fun (_, a, b) -> [ a; b ]) save_pairs

(* "./bright90/mystery-gift/x.png" -> "./mystery-gift/x.png"; the shifted
   frames are png. An unshifted path stays. *)
let unshifted path =
  match String.split_on_char '/' path with
  | [ dot; _shift; folder; frame ] -> String.concat "/" [ dot; folder; frame ]
  | _ -> path

(* A layout's "Last Saved" 18:16 against itself and against 18:18, in one
   shift. *)
let shift_of path = List.nth (String.split_on_char '/' path) 1

let last_saved_cases all =
  let reading k frame =
    List.find_map
      (fun (path, probes) ->
        if shift_of path = k && same (unshifted path) frame then
          Save_dialog.last_saved (measurements probes)
        else None)
      all
  in
  let compare k (_, before, after) () =
    match (reading k before, reading k after) with
    | Some a, Some b ->
        Printf.sprintf "itself %b, 18:16 and 18:18 %b"
          (Save_dialog.same_time a a)
          (Save_dialog.same_time a b)
    | _ -> "no reading"
  in
  List.concat_map
    (fun k ->
      List.map
        (fun ((layout, _, _) as pair) ->
          case
            (Printf.sprintf "Last Saved, %s, %s" layout
               (if k = "mystery-gift" then "as captured" else k))
            (compare k pair) "itself true, 18:16 and 18:18 false")
        save_pairs)
    (List.sort_uniq String.compare (List.map (fun (p, _) -> shift_of p) all))

let pokemon_cell = "boxes, a Pokémon in the cell"

(* What each reader reads on a frame; [name] is the language of the gift
   name's template. *)
let expected_menu path =
  if same path menu then "menu row 0; cards xxxxx." else "no menu"

let expected_list ~name path =
  let listed gift =
    Printf.sprintf "gift list, item 1 selected, the gift item %s" gift
  in
  if same path gift_list then listed (if name = "en" then "4" else "none")
  else if same path french_list then
    listed (if name = "fr" then "4" else "none")
  else "no gift list"

let expected_card path =
  if List.exists (same path) cards_shown then "gift card" else "no gift card"

let expected_boxes path =
  if same path boxes then pokemon_cell
  else
    match box_cell path with
    | Some true -> pokemon_cell
    | Some false -> "boxes, an empty cell"
    | None -> "no boxes"

let expected_save path =
  if List.exists (same path) saves then "save dialog" else "no save dialog"

let readers ~name =
  [
    ("main menu row", menu_text, expected_menu);
    ("gift list", list_text, expected_list ~name);
    ("gift card", card_text, expected_card);
    ("boxes", boxes_text, expected_boxes);
    ("save dialog", save_text, expected_save);
  ]

(* One case per reader per frame, [label] before the frame's path. *)
let frame_cases ?(name = "en") ~label frames =
  List.concat_map
    (fun (path, probes) ->
      List.map
        (fun (reader, read, expected) ->
          case
            (Printf.sprintf "%s%s: %s" label reader path)
            (fun () -> read (measurements probes))
            (expected (unshifted path)))
        (readers ~name))
    frames

let () =
  Table_test.run "gift_readers"
    (frame_cases ~label:"" frames
    @ frame_cases ~label:"shifted, " shifted
    @ frame_cases ~name:"fr" ~label:"French name, " french
    @ last_saved_cases
        (List.filter
           (fun (p, _) -> List.exists (same (unshifted p)) saves)
           shifted
        @ List.filter (fun (p, _) -> List.exists (same p) saves) frames))
