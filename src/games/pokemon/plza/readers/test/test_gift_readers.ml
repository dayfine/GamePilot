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
   name. The zh-Hans list (console B, 2026-11-26, the cursor on the first
   item, Vivillon the 4th as "球球花纹的彩粉蝶") reads as the list, its gift
   item 4 under the zh-Hans name (fixtures/gifts/gifts.zh-Hans.probes.jsonl,
   likewise) and none under the others'. The white fade
   before a card reads as nothing. The same
   list dimmed by the Switch after an idle (gift-list-dimmed, about 30%
   brightness) must read as nothing: a dim screen is no screen we know. No
   other capture reads as the menu, the list or a gift's card. The Boxes and
   the SAVE dialog (console B, 2026-11-25) read as themselves and nothing else
   does; on the Boxes (console B's, Xerneas under the cursor, and the fork's
   box-cells captures) the cursor's cell reads as holding a Pokémon or empty,
   a Pokémon held over an empty cell empty, and the box title reads as Box 1
   on console B's Japanese "ボックス1" of 2026-11-26 alone, in every shift (not
   on its "ボックス3" and "ボックス8", nor the fork's "Box 9" and "Box 24").
   Console B's info cards of 2026-11-26 (a gift received before, a code used
   before; Japanese and zh-Hans) read as the info card by its layout, in
   every shift, and nothing else does. The dialog's "Last Saved" reads the same as itself and not as a copy
   with its 18:16 made 18:18 (synthetic-..., no second save captured), in
   every shift. So does a copy with its date and time where the French game
   shows them (synthetic-save-dialog-fr-layout-..., console B, 2026-11-25:
   no French frame was captured; placed where that run's reading of the old
   time box shows them), whose old box read only the date. Every capture is
   redacted to what its reader probes (images/mystery-gift/README.md,
   images/switch/box-cells/README.md).

   The Japanese main menu (console B, 2026-11-25, the menu captures): at
   1080p its highlighted row and cards read, and its sixth row, Link Play, is
   drawn at the end of 03.15-mable-reward (either row highlighted), in every
   shift. At 360p the menu's buttons do not read, so none reads as the menu;
   their sixth row's edge step still counts in the margins
   (link_play_margins), read from the button, not its name: at least 18.4
   where the row is drawn (1080p and 360p, every shift), at most 7.8 where it
   is not (the five-row menus after Mable's talk, a six-row menu still
   sliding in, the four-row Italian one and the English ones of 01.01),
   against the 13 it needs. The live reads are at 1080p. *)

open Plza_readers
module R = Main_menu_row
module G = Mystery_gift_screen

let frames = Wire.read_image_probes "fixtures/gifts/gifts.probes.jsonl"
let shifted = Wire.read_image_probes "fixtures/gifts/gifts.shifted.probes.jsonl"
let french = Wire.read_image_probes "fixtures/gifts/gifts.fr.probes.jsonl"
let japanese = Wire.read_image_probes "fixtures/gifts/gifts.ja.probes.jsonl"
let chinese = Wire.read_image_probes "fixtures/gifts/gifts.zh-Hans.probes.jsonl"
let measurements probes : Wire.frame = { seq = 1; t_ms = 0.; probes }
let menu = "./tutorial-cards/it-menu-no-card.jpg"

(* The Japanese main menu's captures: the highlighted row and the cards
   (none at 360p, where the menu's buttons do not read), and whether Link Play
   shows. *)
let japanese_menus =
  [
    ("./mystery-gift/menu-six-rows-cursor-on-1.png", Some (0, "xxxxxx"), true);
    ("./mystery-gift/menu-six-rows-cursor-on-6.png", Some (5, "xxxxx."), true);
    ("./mystery-gift/menu-six-rows-cursor-on-1-360p.png", None, true);
    ("./mystery-gift/menu-six-rows-sliding-in-360p.png", None, false);
    ("./mystery-gift/menu-five-rows-cursor-on-1-360p.png", None, false);
    ("./mystery-gift/menu-five-rows-cursor-on-2-360p.png", None, false);
    ("./mystery-gift/menu-five-rows-cursor-on-4-360p.png", None, false);
  ]

let gift_list = "./mystery-gift/gift-list-cursor-on-1.png"
let french_list = "./mystery-gift/gift-list-fr-cursor-on-1.png"
let japanese_list = "./mystery-gift/gift-list-ja-stop-receiving.png"
let chinese_list = "./mystery-gift/gift-list-zh-hans-cursor-on-1.png"

(* Each list's capture, by the language of its names. *)
let lists =
  [
    ("en", gift_list);
    ("fr", french_list);
    ("ja", japanese_list);
    ("zh-Hans", chinese_list);
  ]

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

let link_play_text m =
  if R.link_play_shown m then "Link Play" else "no Link Play"

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
    "./mystery-gift/card-item-ja-360p.png";
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
let box_8 = "./mystery-gift/boxes-box-8-ja-360p.png"
let box_1 = "./mystery-gift/boxes-box-1-ja-360p.png"
let box_3 = "./mystery-gift/boxes-box-3-ja-360p.png"
let box_9 = "./box-cells/pokemon-magikarp-2-0-360p.png"
let box_24 = "./box-cells/empty-2-5-360p.png"

(* The fork's captures of the Boxes (box-cells/: CommandLineTests'
   BoxCellInfoDetector frames at 360p), named by what the cursor is on. *)
let box_cell path =
  match String.split_on_char '/' path with
  | [ _; "box-cells"; frame ] ->
      Some (String.starts_with ~prefix:"pokemon" frame)
  | _ -> None

(* Each "Last Saved" layout's 18:16 and 18:18, and zh-Hans' current time,
   12:12 and its copy made 12:11 (the minutes' "2" replaced by the "1"
   before it). *)
let save_pairs =
  [
    ( "Last Saved, English",
      Save_dialog.last_saved,
      "./mystery-gift/save-dialog-last-saved-1816.png",
      "./mystery-gift/synthetic-save-dialog-last-saved-1818.png" );
    ( "Last Saved, French layout",
      Save_dialog.last_saved,
      "./mystery-gift/synthetic-save-dialog-fr-layout-1816.png",
      "./mystery-gift/synthetic-save-dialog-fr-layout-1818.png" );
    ( "current time, zh-Hans, 12:12 and 12:23 (two runs)",
      Save_dialog.current_time,
      "./mystery-gift/save-dialog-zh-hans-1212-360p.png",
      "./mystery-gift/save-dialog-zh-hans-1223.png" );
    ( "Last Saved, zh-Hans, 12:12 and 12:21 (two runs)",
      Save_dialog.last_saved,
      "./mystery-gift/save-dialog-zh-hans-1212-360p.png",
      "./mystery-gift/save-dialog-zh-hans-1223.png" );
    ( "current time, zh-Hans",
      Save_dialog.current_time,
      "./mystery-gift/save-dialog-zh-hans-1212-360p.png",
      "./mystery-gift/synthetic-save-dialog-zh-hans-1211-360p.png" );
  ]

let saves =
  List.sort_uniq String.compare
    (List.concat_map (fun (_, _, a, b) -> [ a; b ]) save_pairs)

(* "./bright90/mystery-gift/x.png" -> "./mystery-gift/x.png"; the shifted
   frames are png. An unshifted path stays. *)
let unshifted path =
  match String.split_on_char '/' path with
  | [ dot; _shift; folder; frame ] -> String.concat "/" [ dot; folder; frame ]
  | _ -> path

(* A pair's first time against itself and against the other, in one
   shift. *)
let shift_of path = List.nth (String.split_on_char '/' path) 1

let last_saved_cases all =
  let reading k read frame =
    List.find_map
      (fun (path, probes) ->
        if shift_of path = k && same (unshifted path) frame then
          read (measurements probes)
        else None)
      all
  in
  let compare k (_, read, before, after) () =
    match (reading k read before, reading k read after) with
    | Some a, Some b ->
        Printf.sprintf "itself %b, the other %b"
          (Save_dialog.same_time a a)
          (Save_dialog.same_time a b)
    | _ -> "no reading"
  in
  List.concat_map
    (fun k ->
      List.map
        (fun ((layout, _, _, _) as pair) ->
          case
            (Printf.sprintf "%s, %s" layout
               (if k = "mystery-gift" then "as captured" else k))
            (compare k pair) "itself true, the other false")
        save_pairs)
    (List.sort_uniq String.compare (List.map (fun (p, _) -> shift_of p) all))

let pokemon_cell = "boxes, a Pokémon in the cell"

(* What each reader reads on a frame; [name] is the language of the gift
   name's template. *)
let japanese_menu path =
  List.find_opt (fun (frame, _, _) -> same path frame) japanese_menus

let expected_menu path =
  if same path menu then "menu row 0; cards xxxxx."
  else
    match japanese_menu path with
    | Some (_, Some (row, cards), _) ->
        Printf.sprintf "menu row %d; cards %s" row cards
    | Some (_, None, _) | None -> "no menu"

let expected_link_play path =
  match japanese_menu path with
  | Some (_, Some _, true) -> "Link Play"
  | Some _ | None -> "no Link Play"

let expected_list ~name path =
  let listed gift =
    Printf.sprintf "gift list, item 1 selected, the gift item %s" gift
  in
  if same path gift_list then listed (if name = "en" then "4" else "none")
  else if same path after_claim then listed "none"
  else if same path french_list then
    listed (if name = "fr" then "4" else "none")
  else if same path chinese_list then
    listed (if name = "zh-Hans" then "4" else "none")
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
  if same path boxes || same path box_8 then pokemon_cell
  else if same path box_1 || same path box_3 then "boxes, an empty cell"
  else
    match box_cell path with
    | Some true -> pokemon_cell
    | Some false -> "boxes, an empty cell"
    | None -> "no boxes"

let expected_save path =
  if List.exists (same path) saves then "save dialog" else "no save dialog"

(* The box titles read as Box 1 or not, as their frames' boxes are. *)
let box_titles =
  [
    (mg "boxes-box-1-ja-360p", "Box 1");
    (mg "boxes-box-3-ja-360p", "another box");
    (box_8, "another box");
    (box_9, "another box");
    (box_24, "another box");
  ]

let title_text m =
  if not (Boxes_screen.shown m) then "no boxes"
  else
    match Box_title.read m with
    | None -> "no title"
    | Some t -> if Box_title.box_one t then "Box 1" else "another box"

let expected_title path =
  match List.find_opt (fun (f, _) -> same path f) box_titles with
  | Some (_, text) -> text
  | None -> if expected_boxes path = "no boxes" then "no boxes" else "no title"

let info_card_text m = if Info_card.shown m then "info card" else "no info card"

(* Console B's info cards of 2026-11-26: a gift received before and a code
   used before, in Japanese and zh-Hans. *)
let info_cards =
  [
    mg "gift-received-before-ja-360p";
    mg "code-used-before-ja-360p";
    mg "gift-received-before-zh-hans";
    mg "code-used-before-zh-hans-360p";
    mg "code-used-before-zh-hans-2-360p";
  ]

let expected_info_card path =
  if List.exists (same path) info_cards then "info card" else "no info card"

let readers ~name =
  [
    ("main menu row", menu_text, expected_menu);
    ("Link Play row", link_play_text, expected_link_play);
    ("gift list", list_text, expected_list ~name);
    ("gift card", card_text, expected_card);
    ("question", question_text, expected_question);
    ("gift menu", gift_menu_text, expected_gift_menu);
    ("message", message_text, expected_message);
    ("boxes", boxes_text, expected_boxes);
    ("save dialog", save_text, expected_save);
    ("box title", title_text, expected_title);
    ("info card", info_card_text, expected_info_card);
  ]

(* The readers read only once the Mystery Gift screens show: on the story's
   white fades and text boxes the menu's row and a message read too. *)
let gift_screens_only = [ "gift menu"; "message" ]

let in_gifts path =
  match String.split_on_char '/' (unshifted path) with
  | [ _; "mystery-gift"; _ ] -> true
  | _ -> false

(* The info cards' white card covers the gift menu's row and
   items, which read white as on the menu (some shifts read it so): the
   cards are told by their layout, read first. *)
let applies path (reader, _, _) =
  (in_gifts path || not (List.mem reader gift_screens_only))
  && not (reader = "gift menu" && List.exists (same (unshifted path)) info_cards)

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

(* The English main menus of 01.01 (main-menu/, the fork's, 360p): no sixth
   row yet. *)
let early_menus = "./main-menu/en-0101-main-menu"

(* The sixth row's edge step (Main_menu_row.link_play_step) on the Japanese
   menus, the four-row Italian one (every shift) and the English ones: the least where Link Play
   is drawn, at 1080p and at 360p, and the most where it is not, against the
   13 it needs. *)
let link_play_margins () =
  let step probes =
    Option.value ~default:Float.nan (R.link_play_step (measurements probes))
  in
  let menus =
    List.filter_map
      (fun (path, probes) ->
        let frame = unshifted path in
        let small = String.ends_with ~suffix:"360p.png" frame in
        if same frame menu || String.starts_with ~prefix:early_menus frame then
          Some ((false, small), step probes)
        else
          Option.map
            (fun (_, _, shown) -> ((shown, small), step probes))
            (japanese_menu frame))
      (frames @ shifted)
  in
  let fold group f init =
    List.fold_left
      (fun acc (g, v) -> if group g then f acc v else acc)
      init menus
  in
  Printf.sprintf
    "drawn from %.1f at 1080p, from %.1f at 360p; not drawn up to %.1f (%d \
     frames)"
    (fold (fun (shown, small) -> shown && not small) Float.min 1000.)
    (fold (fun (shown, small) -> shown && small) Float.min 1000.)
    (fold (fun (shown, _) -> not shown) Float.max (-1000.))
    (List.length menus)

let () =
  Table_test.run "gift_readers"
    (frame_cases ~label:"" frames
    @ frame_cases ~label:"shifted, " shifted
    @ frame_cases ~name:"fr" ~label:"French name, " french
    @ frame_cases ~name:"ja" ~label:"Japanese name, " japanese
    @ frame_cases ~name:"zh-Hans" ~label:"Chinese name, " chinese
    @ gift_item_cases ~name:"en" ~label:"" (frames @ shifted)
    @ gift_item_cases ~name:"fr" ~label:"French name, " french
    @ gift_item_cases ~name:"ja" ~label:"Japanese name, " japanese
    @ gift_item_cases ~name:"zh-Hans" ~label:"Chinese name, " chinese
    @ [
        case "Link Play's edges, the Japanese, Italian and English menus"
          link_play_margins
          "drawn from 18.4 at 1080p, from 18.9 at 360p; not drawn up to 7.8 \
           (82 frames)";
      ]
    @ last_saved_cases
        (List.filter
           (fun (p, _) -> List.exists (same (unshifted p)) saves)
           shifted
        @ List.filter (fun (p, _) -> List.exists (same p) saves) frames))
