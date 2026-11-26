open Frlg_readers
module M = Menu_input
module Text = Frlg_text

type row = Item of { named : bool; count : int } | Cancel

type game_steps = {
  open_withdraw : unit -> unit;
  read_row : int -> string -> row option;
  cursor_row : unit -> int option;
  press : Wire.button -> unit;
  await_quantity : unit -> bool;
  read_quantity : unit -> int option;
  close : unit -> unit;
}

type stock = { items : int; stacks : (int * int) list }

let slots = 30
let last_shown = Bag_items.shown_rows - 1

(* Row [k] of the list, from the top, once [taps] DOWNs went in: the taps it
   needs pressed, then the shown row it is on. *)
let reveal steps ~taps k =
  let need = Bag_items.taps_to_reveal k in
  for _ = taps + 1 to need do
    steps.press Wire.Down
  done;
  (max taps need, if k < Bag_items.shown_rows then k else last_shown)

let scan steps name =
  let rec go k taps stacks =
    if k > slots then M.fail "item_storage_unread" "no CANCEL after 30 rows"
    else
      let taps, shown = reveal steps ~taps k in
      match steps.read_row shown name with
      | Some Cancel -> { items = k; stacks = List.rev stacks }
      | Some (Item { named; count }) ->
          go (k + 1) taps (if named then (k, count) :: stacks else stacks)
      | None ->
          M.fail "item_storage_unread"
            (Printf.sprintf "list row %d reads as no item and no CANCEL" k)
  in
  go 0 0 []

let tens = 10

let quantity_press ~now ~target ~stack =
  if now = target then None
  else if now = 1 && target = stack then Some Wire.Down
  else if target - now >= tens then Some Wire.Right
  else if now - target >= tens then Some Wire.Left
  else if target > now then Some Wire.Up
  else Some Wire.Down

let max_quantity_presses = 200

let rec set_quantity steps ~target ~stack presses =
  match steps.read_quantity () with
  | None -> M.fail "item_storage_quantity" "the quantity does not read"
  | Some now -> (
      match quantity_press ~now ~target ~stack with
      | None -> ()
      | Some _ when presses = 0 ->
          M.fail "item_storage_quantity"
            (Printf.sprintf "the quantity stays at %d, not %d" now target)
      | Some b ->
          steps.press b;
          set_quantity steps ~target ~stack (presses - 1))

(* After {!scan} the cursor is on CANCEL, list row [items]; UP to the
   stack's row [k], which is then on the cursor's shown row. *)
let to_stack steps name ~items (k, count) =
  for _ = k + 1 to items do
    steps.press Wire.Up
  done;
  match steps.cursor_row () with
  | Some r when steps.read_row r name = Some (Item { named = true; count }) ->
      ()
  | _ ->
      M.fail "item_storage_cursor"
        (Printf.sprintf "the cursor is not on %s x%d" name count)

let withdraw steps ~log name count =
  steps.open_withdraw ();
  let stock = scan steps name in
  match List.find_opt (fun (_, c) -> c >= count) stock.stacks with
  | None ->
      M.fail "item_storage_missing"
        (Printf.sprintf "no stack of %s with %d" name count)
  | Some ((_, have) as stack) ->
      to_stack steps name ~items:stock.items stack;
      steps.press Wire.A;
      steps.press Wire.A;
      if have > 1 then (
        if not (steps.await_quantity ()) then
          M.fail "item_storage_no_quantity" "WITHDRAW shows no quantity box";
        set_quantity steps ~target:count ~stack:have max_quantity_presses;
        steps.press Wire.A);
      steps.press Wire.A;
      log (Printf.sprintf "Item storage: withdrew %d %s of %d." count name have);
      steps.close ()

let check steps ~log name count =
  steps.open_withdraw ();
  let stock = scan steps name in
  steps.close ();
  log
    (Printf.sprintf "Item storage: %d items; %s %s." stock.items name
       (String.concat ", "
          (List.map (fun (_, c) -> Printf.sprintf "x%d" c) stock.stacks)));
  if stock.items >= slots then
    M.fail "item_storage_full"
      (Printf.sprintf "%d items stored: the code's slot 30 is taken" stock.items);
  match count with
  | Some n when not (List.exists (fun (_, c) -> c = n) stock.stacks) ->
      M.fail "item_storage_missing" (Printf.sprintf "no %s x%d" name n)
  | _ -> ()

(* The game's steps. Presses and waits measured on mGBA (2026-11-25). *)
let hold_ms = 100
let menu_ms = 500
let screen_ms = 1500
let look_timeout_ms = 1000
let screen_timeout_ms = 4000
let max_opening_looks = 16
let max_count_digits = 3
let cancel = "CANCEL"

let press_wait ms b =
  ignore (Effects.submit [ M.hold ~hold_ms ~cooldown_ms:ms b ])

let press b =
  match b with Wire.A | Wire.B -> press_wait screen_ms b | _ -> press_wait menu_ms b

let looking f =
  Effects.with_probes (Pc_screen.probes @ Item_pc_screen.probes) (fun () ->
      match Effects.await ~timeout_ms:look_timeout_ms (fun _ -> true) with
      | Holds m -> Some (f m)
      | Timeout -> None)

let text line candidates =
  match Text.Line_reading.read (Text_data.glyphs ()) line candidates with
  | Read { text; _ } -> Some text
  | No_match _ -> None

let menu_label row candidates = text (Text.Text_lines.pc_menu_row row) candidates

(* The PC's menus, from pokefirered pc.inc and player_pc.c: the PC list's
   second row is the player's PC; its menu ITEM STORAGE, MAILBOX, TURN OFF;
   ITEM STORAGE's WITHDRAW ITEM, DEPOSIT ITEM, TOSS ITEM, CANCEL. *)
let player_pc_row = 1
let item_storage = "ITEM STORAGE"
let withdraw_item = "WITHDRAW ITEM"

type opening = Booting | On_list | In_player_pc | In_storage

let rec open_next stage looks =
  if looks = 0 then M.fail "item_storage_open" "WITHDRAW ITEM's list did not open"
  else
    let view = looking (fun m -> (Pc_screen.read m, Item_pc_screen.shown m)) in
    match (stage, view) with
    | _, Some (_, Some true) -> ()
    | Booting, Some ({ screen = Pc_list; cursor = Some r }, _) ->
        if r < player_pc_row then press Wire.Down
        else if r > player_pc_row then press Wire.Up
        else press Wire.A;
        open_next (if r = player_pc_row then On_list else Booting) (looks - 1)
    | Booting, Some ({ screen = Overworld | Text; _ }, _) ->
        press Wire.A;
        open_next Booting (looks - 1)
    | (On_list | In_player_pc), Some ({ cursor = Some 0; _ }, _)
      when menu_label 0 [ item_storage ] = Some item_storage ->
        press Wire.A;
        open_next In_player_pc (looks - 1)
    | (On_list | In_player_pc), Some ({ cursor = Some 0; _ }, _)
      when menu_label 0 [ withdraw_item ] = Some withdraw_item ->
        press Wire.A;
        open_next In_storage (looks - 1)
    | (On_list | In_player_pc | In_storage), Some ({ screen = Text; _ }, _) ->
        press Wire.A;
        open_next stage (looks - 1)
    | _ ->
        press_wait menu_ms Wire.Up;
        open_next stage (looks - 1)

let read_count row =
  Text.Number_reading.read_right_aligned
    ~max_score:Text.Number_reading.small_max_score
    (Text_data.small_glyphs ())
    (Text.Text_lines.item_pc_count_digit row)
    ~max_cells:max_count_digits

let read_row i name =
  match text (Text.Text_lines.item_pc_row i) [ name; cancel ] with
  | Some t when t = cancel -> Some Cancel
  | named -> (
      match read_count i with
      | Some count -> Some (Item { named = named = Some name; count })
      | None -> None)

let read_quantity () =
  Text.Number_reading.read_left_aligned
    ~max_score:Text.Number_reading.small_max_score
    (Text_data.small_glyphs ())
    Text.Text_lines.item_pc_quantity_digit ~max_cells:max_count_digits

let await_on f =
  Effects.with_probes Item_pc_screen.probes (fun () ->
      match Effects.await ~timeout_ms:screen_timeout_ms f with
      | Holds _ -> true
      | Timeout -> false)

let close_presses = 4

let close ~log () =
  for _ = 1 to close_presses do
    press Wire.B
  done;
  M.settle_back ~label:"item storage" ~log

let screen_game_steps ~log =
  {
    open_withdraw = (fun () -> open_next Booting max_opening_looks);
    read_row;
    cursor_row =
      (fun () -> Option.join (looking Item_pc_screen.cursor_row));
    press;
    await_quantity =
      (fun () -> await_on (fun m -> Item_pc_screen.quantity_shown m = Some true));
    read_quantity;
    close = close ~log;
  }

let display_name ~where slug =
  let names =
    List.concat_map
      (Text.Item_names.in_pocket (Text_data.item_names ()))
      [ Items; Poke_balls; Tm_case; Berry_pouch ]
  in
  match Bag_items.display_name names slug with
  | Some n -> n
  | None -> Json_field.fail "%s: no item named %s" where slug

let check_args ~where args =
  ( display_name ~where (Json_field.string ~where "item" args),
    if Json_field.has "count" args then
      Some (Json_field.int ~where "count" args)
    else None )

let withdraw_args ~where args =
  ( display_name ~where (Json_field.string ~where "item" args),
    Json_field.int ~where "count" args )

let run_with ~action read perform (_ : Pokemon_engine.Plan.event) args =
  Result.bind (Action_args.decode ~action read args) (fun v ->
      M.run (fun () -> perform v))

let handlers ~log =
  [
    ( "check_item_storage",
      run_with ~action:"check_item_storage" check_args (fun (name, count) ->
          check (screen_game_steps ~log) ~log name count) );
    ( "withdraw_from_item_storage",
      run_with ~action:"withdraw_from_item_storage" withdraw_args
        (fun (name, count) ->
          withdraw (screen_game_steps ~log) ~log name count) );
  ]
