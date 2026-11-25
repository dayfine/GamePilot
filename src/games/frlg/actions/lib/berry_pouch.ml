open Frlg_readers
module M = Menu_input
module Text = Frlg_text

let is_berry slug = String.ends_with ~suffix:"-berry" slug
let shown_rows = 7
let scroll_downs = 3

(* The fork's MAX_BERRIES: rows looked at before giving up. *)
let max_berries = 43

let berry_number slug =
  let berries =
    Text.Item_names.in_pocket (Text_data.item_names ()) Berry_pouch
  in
  Option.bind (Bag_items.display_name berries slug) (fun name ->
      Option.map succ (List.find_index (String.equal name) berries))

let probes = Berry_pouch_screen.probes
let shows_pouch = Berry_pouch_screen.berry_pouch
let key_open_row = 0

(* The fork's presses and waits: OPEN taken (2000 ms), the cursor sent up 12
   times, the list scrolled down and back up, each DOWN in a menu; each A
   160 ms held, then 800 ms on the berry, 1500 ms on GIVE. *)
let pouch_open_ms = 2000
let reset_ups = 12
let reset_hold_ms = 80
let reset_release_ms = 100
let scroll_hold_ms = 100
let scroll_release_ms = 350
let back_up_hold_ms = 80
let back_up_release_ms = 120
let menu_hold_ms = 100
let menu_release_ms = 250
let berry_menu_ms = 800
let give_taken_ms = 1500

let presses ~n ~hold_ms ~cooldown_ms button =
  if n > 0 then
    ignore
      (Effects.submit
         (List.init n (fun _ -> M.hold ~hold_ms ~cooldown_ms button)))

let open_pouch () =
  Bag_items.item_action "berry-pouch" key_open_row;
  Effects.submit [ Wire.Wait { wait_ms = pouch_open_ms } ] |> ignore;
  ignore (M.await_screen ~code:"no_berry_pouch" "the Berry Pouch" shows_pouch);
  presses ~n:reset_ups ~hold_ms:reset_hold_ms ~cooldown_ms:reset_release_ms
    Wire.Up

let max_number_digits = 2

let number_on_row row =
  Text.Number_reading.read_left_aligned
    ~max_score:Text.Number_reading.small_max_score
    (Text_data.small_glyphs ())
    (Text.Text_lines.berry_pouch_number_digit row)
    ~max_cells:max_number_digits

let rec find_shown target row =
  if row >= shown_rows then None
  else if number_on_row row = Some target then Some row
  else find_shown target (row + 1)

let scroll_down () =
  presses ~n:1 ~hold_ms:scroll_hold_ms ~cooldown_ms:scroll_release_ms Wire.Down

(* One more row on the bottom row per DOWN, from list row [index]; the DOWNs
   pressed so far in [downs]. *)
let rec scroll target index last downs =
  if index >= max_berries then (None, downs)
  else (
    scroll_down ();
    match number_on_row (shown_rows - 1) with
    | Some n when n = target -> (Some index, downs + 1)
    | Some n when Some n <> last ->
        scroll target (index + 1) (Some n) (downs + 1)
    | _ -> (None, downs + 1))

let find_row target =
  match find_shown target 0 with
  | Some row -> Some row
  | None ->
      presses ~n:scroll_downs ~hold_ms:scroll_hold_ms
        ~cooldown_ms:scroll_release_ms Wire.Down;
      let found, downs = scroll target shown_rows None scroll_downs in
      presses ~n:downs ~hold_ms:back_up_hold_ms ~cooldown_ms:back_up_release_ms
        Wire.Up;
      found

let give_row = 1

let menu_tap ~n =
  presses ~n ~hold_ms:menu_hold_ms ~cooldown_ms:menu_release_ms Wire.Down

let give_from_row row =
  menu_tap ~n:row;
  M.press Wire.A ~cooldown_ms:berry_menu_ms;
  menu_tap ~n:give_row;
  M.press Wire.A ~cooldown_ms:give_taken_ms

let row_of slug number =
  Effects.with_probes probes open_pouch;
  match Effects.with_probes probes (fun () -> find_row number) with
  | Some row -> row
  | None -> M.fail "not_in_bag" (slug ^ " is not in the Berry Pouch")

let choose_give slug =
  match berry_number slug with
  | None -> M.fail ~repeats:true "unknown_item" (slug ^ " is no berry's name")
  | Some number -> give_from_row (row_of slug number)
