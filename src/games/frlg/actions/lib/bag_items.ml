open Frlg_readers
module M = Menu_input
module Text = Frlg_text

let bag_row = 2
let shown_rows = 6
let scroll_row = 3

(* The game's é is two UTF-8 bytes; a slug spells it e. *)
let e_acute = "\xc3\xa9"

let rec plain_e text =
  match Str_search.find text e_acute with
  | None -> text
  | Some i ->
      plain_e
        (String.sub text 0 i ^ "e"
        ^ String.sub text (i + 2) (String.length text - i - 2))

let normalize name =
  plain_e (String.lowercase_ascii name)
  |> String.map (fun c -> if c = ' ' then '-' else c)

let display_name names slug =
  List.find_opt (fun name -> normalize name = slug) names

let is_key_item slug =
  let key_items =
    Text.Item_names.in_pocket (Text_data.item_names ()) Key_items
  in
  Option.is_some (display_name key_items slug)

let pocket_of_item slug : Bag_screen.pocket =
  if String.ends_with ~suffix:"-ball" slug then Poke_balls
  else if is_key_item slug then Key_items
  else Items

let taps_to_reveal k =
  if k < shown_rows then 0 else k - (shown_rows - 1) + scroll_row

let order : Bag_screen.pocket list = [ Items; Key_items; Poke_balls ]
let index pocket = Option.get (List.find_index (fun p -> p = pocket) order)

let other_pocket p m =
  match Bag_screen.pocket m with Some q -> q <> p | None -> false

(* One pocket toward the target, then the pocket read again. *)
let pocket_turn_ms = 1000

(* A tap the bag takes before it is ready is lost: tapped again until the
   pocket changes. *)
let step_from p pocket =
  M.press_until ~max_presses:4 ~code:"no_pocket" "the next pocket"
    (if index p < index pocket then Wire.Right else Wire.Left)
    ~cooldown_ms:pocket_turn_ms (other_pocket p)

(* The arrows hide while a pocket slides in: the pocket reads once they show. *)
let pocket_shown m = Bag_screen.bag_open m && Bag_screen.pocket m <> None

let rec turn_from tries pocket =
  let m = M.await_screen ~code:"no_bag" "the bag" pocket_shown in
  match Bag_screen.pocket m with
  | Some p when p = pocket -> ()
  | Some p when tries < List.length order ->
      step_from p pocket;
      turn_from (tries + 1) pocket
  | _ -> M.fail "no_pocket" (Bag_screen.pocket_name pocket ^ " did not open")

let turn_to pocket = turn_from 0 pocket
let max_list_rows = 60

let to_top () =
  M.press_until ~max_presses:max_list_rows ~code:"no_pocket" "the list's top"
    Wire.Up ~cooldown_ms:M.tap_release_ms (fun m ->
      Bag_screen.cursor_row m = Some 0)

let pocket_top pocket =
  turn_to pocket;
  to_top ()

let open_pocket_top pocket =
  Menu_cursor.open_start_menu_row bag_row;
  pocket_top pocket

let text_pocket : Bag_screen.pocket -> Text.Item_names.pocket = function
  | Items -> Items
  | Key_items -> Key_items
  | Poke_balls -> Poke_balls

let cancel = "CANCEL"

let read_row candidates row =
  match
    Text.Line_reading.read (Text_data.glyphs ())
      (Text.Text_lines.bag_row row)
      candidates
  with
  | Read { text; _ } -> Some text
  | No_match _ -> None

type found = Found of { index : int; row : int } | Absent | Unread

(* Reads list rows from [k] on (the first six by their screen row, then each
   one tap further on the bottom row) until the item ([Found] with its list
   index and screen row) or the list's end ([Absent]); [Unread] for a row that did not read. *)
let rec find_from candidates name k =
  let taps = taps_to_reveal k in
  M.taps Wire.Down (taps - taps_to_reveal (k - 1));
  let row = if taps > 0 then shown_rows - 1 else k in
  match read_row candidates row with
  | Some text when text = name -> Found { index = k; row }
  | Some text when text = cancel -> Absent
  | Some _ when k < max_list_rows -> find_from candidates name (k + 1)
  | _ -> Unread

let max_count_digits = 3

let count_on_row row =
  Text.Number_reading.read_right_aligned
    ~max_score:Text.Number_reading.small_max_score
    (Text_data.small_glyphs ())
    (Text.Text_lines.bag_count_digit row)
    ~max_cells:max_count_digits

let cursor_text candidates =
  let m =
    M.await_screen ~code:"no_bag" "the bag's cursor" (fun m ->
        Option.is_some (Bag_screen.cursor_row m))
  in
  let row = Option.get (Bag_screen.cursor_row m) in
  (row, read_row candidates row)

(* DOWN until the cursor's row reads the item: the cursor stays on the
   window's fourth row while the list scrolls under it, so the name, not the
   row, says where it is. A tap the bag did not take is tapped again. *)
let tap_down_from row =
  M.taps Wire.Down 1;
  ignore
    (Effects.await ~timeout_ms:Frlg_menu_cursor.Cursor_steps.tap_timeout_ms
       (fun m -> Bag_screen.cursor_row m <> Some row))

let rec down_to candidates name presses =
  match cursor_text candidates with
  | _, Some text when text = name -> ()
  | row, _ when presses < max_list_rows ->
      tap_down_from row;
      down_to candidates name (presses + 1)
  | _ -> M.fail "not_in_bag" (name ^ " did not come under the cursor")

(* The pocket's names (CANCEL first) and the slug's own among them. *)
let pocket_names slug =
  let pocket = pocket_of_item slug in
  let in_pocket =
    Text.Item_names.in_pocket (Text_data.item_names ()) (text_pocket pocket)
  in
  match display_name in_pocket slug with
  | None -> M.fail ~repeats:true "unknown_item" (slug ^ " is no item name")
  | Some name -> (pocket, cancel :: in_pocket, name)

let select slug =
  let pocket, candidates, name = pocket_names slug in
  match find_from candidates name 0 with
  | Found _ -> down_to candidates name 0
  | Absent | Unread ->
      M.fail "not_in_bag" (slug ^ " is not in " ^ Bag_screen.pocket_name pocket)

let count ~log slug =
  let pocket, candidates, name = pocket_names slug in
  open_pocket_top pocket;
  let counted =
    match find_from candidates name 0 with
    | Found { row; _ } -> count_on_row row
    | Absent -> Some 0
    | Unread -> None
  in
  log
    (match counted with
    | Some n -> Printf.sprintf "Bag: %d %s." n slug
    | None -> Printf.sprintf "Bag: the count of %s did not read." slug);
  M.close "the bag" Bag_screen.bag_open;
  M.settle_back ~label:"bag count" ~log;
  counted

let list_row slug =
  let _, candidates, name = pocket_names slug in
  match find_from candidates name 0 with
  | Found { index; _ } -> Some index
  | Absent | Unread -> None

(* A row that reads no name (the list not drawn yet, after the mail editor) is
   no count, not "not there" (mg-06 testing run 5 read 0 so). *)
let count_in_pocket slug =
  let _, candidates, name = pocket_names slug in
  match find_from candidates name 0 with
  | Found { row; _ } -> count_on_row row
  | Absent -> Some 0
  | Unread -> None

let item_action item row =
  open_pocket_top (pocket_of_item item);
  select item;
  M.press Wire.A;
  ignore
    (M.await_screen ~code:"no_item_menu" ("the menu of " ^ item)
       Bag_screen.item_menu);
  M.taps Wire.Down row;
  M.press Wire.A
