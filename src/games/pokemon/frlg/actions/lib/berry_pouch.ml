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
type tap = { hold_ms : int; release_ms : int }

let reset_tap = { hold_ms = 80; release_ms = 100 }
let scroll_tap = { hold_ms = 100; release_ms = 350 }
let back_up_tap = { hold_ms = 80; release_ms = 120 }
let menu_tap_timing = { hold_ms = 100; release_ms = 250 }

type pouch_waits = {
  pouch_open_ms : int;
  reset_ups : int;
  berry_menu_ms : int;
  give_taken_ms : int;
}

let waits =
  {
    pouch_open_ms = 2000;
    reset_ups = 12;
    berry_menu_ms = 800;
    give_taken_ms = 1500;
  }

let presses ~n (t : tap) button =
  let cmd = M.hold ~hold_ms:t.hold_ms ~cooldown_ms:t.release_ms button in
  if n > 0 then ignore (Effects.submit (List.init n (fun _ -> cmd)))

let open_pouch () =
  Bag_items.item_action "berry-pouch" key_open_row;
  Effects.submit [ Wire.Wait { wait_ms = waits.pouch_open_ms } ] |> ignore;
  ignore (M.await_screen ~code:"no_berry_pouch" "the Berry Pouch" shows_pouch);
  presses ~n:waits.reset_ups reset_tap Wire.Up

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

let scroll_down () = presses ~n:1 scroll_tap Wire.Down

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
      presses ~n:scroll_downs scroll_tap Wire.Down;
      let found, downs = scroll target shown_rows None scroll_downs in
      presses ~n:downs back_up_tap Wire.Up;
      found

let give_row = 1
let menu_tap ~n = presses ~n menu_tap_timing Wire.Down

let give_from_row row =
  menu_tap ~n:row;
  M.press Wire.A ~cooldown_ms:waits.berry_menu_ms;
  menu_tap ~n:give_row;
  M.press Wire.A ~cooldown_ms:waits.give_taken_ms

let row_of slug number =
  Effects.with_probes probes open_pouch;
  match Effects.with_probes probes (fun () -> find_row number) with
  | Some row -> row
  | None -> M.fail "not_in_bag" (slug ^ " is not in the Berry Pouch")

let choose_give slug =
  match berry_number slug with
  | None -> M.fail ~repeats:true "unknown_item" (slug ^ " is no berry's name")
  | Some number -> give_from_row (row_of slug number)

let find_shown_row target =
  match find_shown target 0 with
  | Some row -> Some row
  | None -> (
      presses ~n:scroll_downs scroll_tap Wire.Down;
      match scroll target shown_rows None scroll_downs with
      | Some _, _ -> Some (shown_rows - 1)
      | None, _ -> None)

let bag_or_pouch m = Bag_screen.bag_open m || shows_pouch m

let read_count number =
  match find_shown_row number with
  | Some row -> Bag_items.count_on_row row
  | None -> Some 0

let log_count ~log slug = function
  | Some n -> log (Printf.sprintf "Berry Pouch: %d %s." n slug)
  | None ->
      log (Printf.sprintf "Berry Pouch: the count of %s did not read." slug)

let count_number ~log slug number =
  Effects.with_probes probes open_pouch;
  let counted = Effects.with_probes probes (fun () -> read_count number) in
  log_count ~log slug counted;
  Effects.with_probes probes (fun () ->
      M.close_through_fades "the bag" bag_or_pouch);
  M.settle_back ~label:"berry count" ~log;
  counted

let count ~log slug =
  match berry_number slug with
  | None -> M.fail ~repeats:true "unknown_item" (slug ^ " is no berry's name")
  | Some number -> count_number ~log slug number
