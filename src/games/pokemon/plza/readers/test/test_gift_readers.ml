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
   shifts) its gift is item 4 and the English list has none. The Japanese
   list under "stop receiving?" (console B, 2026-11-25, the cursor on the
   first item, Vivillon the 4th as "ボールのもようの　ビビヨン") reads as no
   list and no card; its gift is item 4 under the Japanese name
   (fixtures/gifts/gifts.ja.probes.jsonl, likewise) and none under the
   English or French one, and the other lists have none under the Japanese
   name. The white fade
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
let japanese = Wire.read_image_probes "fixtures/gifts/gifts.ja.probes.jsonl"
let measurements probes : Wire.frame = { seq = 1; t_ms = 0.; probes }
let menu = "./tutorial-cards/it-menu-no-card.jpg"
let gift_list = "./mystery-gift/gift-list-cursor-on-1.png"
let french_list = "./mystery-gift/gift-list-fr-cursor-on-1.png"
let japanese_list = "./mystery-gift/gift-list-ja-stop-receiving.png"

(* Each list's capture, by the language of its names. *)
let lists = [ ("en", gift_list); ("fr", french_list); ("ja", japanese_list) ]

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

let question_text m =
  match G.question m with
  | Some Yes -> "question, Yes highlighted"
  | Some No -> "question, No highlighted"
  | None -> "no question"

let gift_menu_text m = if G.gift_menu m then "gift menu" else "no gift menu"
let message_text m = if G.message m then "message" else "no message"

let boxes_text m =
  if not (Boxes_screen.shown m) then "no boxes"
  else if Box_cell.holds_pokemon m then "boxes, a Pokémon in the cell"
  else "boxes, an empty cell"

let save_text m =
  if Save_dialog.shown m then "save dialog" else "no save dialog"

let same a b = Filename.remove_extension a = Filename.remove_extension b

let cards_shown =
  [
    "./mystery-gift/card-vivillon.png";
    "./mystery-gift/card-vivillon-ja.png";
    "./mystery-gift/card-vivillon-ja-360p.png";
  ]

(* Console B's Japanese 360p frames (2026-11-25): the list after Vivillon
   was claimed (three gifts, the cursor on the first), the Yes/No questions
   and the Mystery Gift menu. *)
let after_claim = "./mystery-gift/gift-list-ja-after-claim-360p.png"
let mg k = "./mystery-gift/" ^ k ^ ".png"

let questions =
  [
    (mg "gift-list-ja-stop-receiving-yes-360p", "question, Yes highlighted");
    (mg "gift-list-ja-stop-receiving-no-360p", "question, No highlighted");
    (mg "gift-menu-ja-report-question-360p", "question, Yes highlighted");
  ]

let gift_menus =
  [
    mg "gift-menu-ja-360p";
    mg "gift-menu-ja-connected-message-360p";
    mg "gift-menu-ja-report-question-360p";
  ]

let messages = [ mg "gift-menu-ja-connected-message-360p" ]
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
  else if same path after_claim then listed "none"
  else if same path french_list then
    listed (if name = "fr" then "4" else "none")
  else "no gift list"

let expected_card path =
  if List.exists (same path) cards_shown then "gift card" else "no gift card"

let expected_question path =
  Option.value ~default:"no question"
    (List.find_map
       (fun (q, text) -> if same path q then Some text else None)
       questions)

let expected_gift_menu path =
  if List.exists (same path) gift_menus then "gift menu" else "no gift menu"

let expected_message path =
  if List.exists (same path) messages then "message" else "no message"

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
    ("question", question_text, expected_question);
    ("gift menu", gift_menu_text, expected_gift_menu);
    ("message", message_text, expected_message);
    ("boxes", boxes_text, expected_boxes);
    ("save dialog", save_text, expected_save);
  ]

(* The readers read only once the Mystery Gift screens show: on the story's
   white fades and text boxes the menu's row and a message read too. *)
let gift_screens_only = [ "gift menu"; "message" ]

let in_gifts path =
  match String.split_on_char '/' (unshifted path) with
  | [ _; "mystery-gift"; _ ] -> true
  | _ -> false

let applies path (reader, _, _) =
  in_gifts path || not (List.mem reader gift_screens_only)

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
        (List.filter (applies path) (readers ~name)))
    frames

(* The gift's item on each list's frames, [name] the language of the gift
   name's template: item 4 on the list in that language, none on the
   others. *)
let gift_item_cases ~name ~label frames =
  List.filter_map
    (fun (path, probes) ->
      Option.map
        (fun (language, _) ->
          case
            (Printf.sprintf "%sthe gift's item: %s" label path)
            (fun () -> item (G.gift_item (measurements probes)))
            (if language = name then "4" else "none"))
        (List.find_opt (fun (_, list) -> same (unshifted path) list) lists))
    frames

let () =
  Table_test.run "gift_readers"
    (frame_cases ~label:"" frames
    @ frame_cases ~label:"shifted, " shifted
    @ frame_cases ~name:"fr" ~label:"French name, " french
    @ frame_cases ~name:"ja" ~label:"Japanese name, " japanese
    @ gift_item_cases ~name:"en" ~label:"" (frames @ shifted)
    @ gift_item_cases ~name:"fr" ~label:"French name, " french
    @ gift_item_cases ~name:"ja" ~label:"Japanese name, " japanese
    @ last_saved_cases
        (List.filter
           (fun (p, _) -> List.exists (same (unshifted p)) saves)
           shifted
        @ List.filter (fun (p, _) -> List.exists (same p) saves) frames))
