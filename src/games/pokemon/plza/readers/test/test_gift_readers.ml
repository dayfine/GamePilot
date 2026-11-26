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
   images/switch/box-cells/README.md).

   The Japanese main menu (console B, 2026-11-25, the menu captures): at
   1080p its highlighted row and cards read, and its sixth row, Link Play,
   shows at the end of 03.15-mable-reward (either row highlighted), in every
   shift. At 360p the menu's buttons do not read, so none reads as the menu;
   their sixth band still counts in the margins (link_play_margins): Link
   Play's band is at least 0.082 white at 1080p and 0.061 at 360p, but 0.008
   at 360p dimmed 10% (its small text under 221); 0.000 on the five-row menus
   after Mable's talk, on a six-row menu still sliding in and on the Italian
   four-row one, against the 0.03 it needs. The live reads are at 1080p. *)

open Plza_readers
module R = Main_menu_row
module G = Mystery_gift_screen

let frames = Wire.read_image_probes "fixtures/gifts/gifts.probes.jsonl"
let shifted = Wire.read_image_probes "fixtures/gifts/gifts.shifted.probes.jsonl"
let french = Wire.read_image_probes "fixtures/gifts/gifts.fr.probes.jsonl"
let japanese = Wire.read_image_probes "fixtures/gifts/gifts.ja.probes.jsonl"
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

let link_play_text m =
  if R.link_play_shown m then "Link Play" else "no Link Play"

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
    ("Link Play row", link_play_text, expected_link_play);
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

(* The sixth band's white share on the Japanese menus and the four-row
   Italian one, every shift: the least where Link Play shows, at 1080p and at
   360p (dimmed 10% apart), and the most where it does not, against the 0.03
   it needs. *)
let link_play_margins () =
  let band5 probes = List.nth (R.white_shares (measurements probes)) 5 in
  let menus =
    List.filter_map
      (fun (path, probes) ->
        let frame = unshifted path in
        let small = String.ends_with ~suffix:"360p.png" frame in
        let dim = shift_of path = "bright90" in
        if same frame menu then Some ((false, small, dim), band5 probes)
        else
          Option.map
            (fun (_, _, shown) -> ((shown, small, dim), band5 probes))
            (japanese_menu frame))
      (frames @ shifted)
  in
  let least group =
    List.fold_left
      (fun acc (g, share) -> if group g then Float.min acc share else acc)
      1. menus
  in
  let most =
    List.fold_left
      (fun acc ((shown, _, _), share) ->
        if shown then acc else Float.max acc share)
      0. menus
  in
  Printf.sprintf
    "shown from %.3f at 1080p, from %.3f at 360p (%.3f dimmed 10%%); not shown \
     up to %.3f"
    (least (fun (shown, small, _) -> shown && not small))
    (least (fun (shown, small, dim) -> shown && small && not dim))
    (least (fun (shown, small, dim) -> shown && small && dim))
    most

let () =
  Table_test.run "gift_readers"
    (frame_cases ~label:"" frames
    @ frame_cases ~label:"shifted, " shifted
    @ frame_cases ~name:"fr" ~label:"French name, " french
    @ frame_cases ~name:"ja" ~label:"Japanese name, " japanese
    @ gift_item_cases ~name:"en" ~label:"" (frames @ shifted)
    @ gift_item_cases ~name:"fr" ~label:"French name, " french
    @ gift_item_cases ~name:"ja" ~label:"Japanese name, " japanese
    @ [
        case "Link Play's band, the Japanese menus in every shift"
          link_play_margins
          "shown from 0.082 at 1080p, from 0.061 at 360p (0.008 dimmed 10%); \
           not shown up to 0.000";
      ]
    @ last_saved_cases
        (List.filter
           (fun (p, _) -> List.exists (same (unshifted p)) saves)
           shifted
        @ List.filter (fun (p, _) -> List.exists (same p) saves) frames))
