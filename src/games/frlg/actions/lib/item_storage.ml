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

type stock = { items : int; stacks : (int * int) list; cursor : int }

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

let fail_unread k =
  M.fail "item_storage_unread"
    (Printf.sprintf "list row %d reads as no item and no CANCEL" k)

let rec scan_from steps name k taps stacks =
  if k > slots then M.fail "item_storage_unread" "no CANCEL after 30 rows";
  let taps, shown = reveal steps ~taps k in
  match steps.read_row shown name with
  | Some Cancel -> { items = k; stacks = List.rev stacks; cursor = taps }
  | Some (Item { named = true; count }) ->
      scan_from steps name (k + 1) taps ((k, count) :: stacks)
  | Some (Item _) -> scan_from steps name (k + 1) taps stacks
  | None -> fail_unread k

let scan steps name = scan_from steps name 0 0 []
let max_quantity_presses = 200

let quantity_stuck now target =
  M.fail "item_storage_quantity"
    (Printf.sprintf "the quantity stays at %d, not %d" now target)

let rec set_quantity steps ~target ~stack presses =
  let now =
    match steps.read_quantity () with
    | Some n -> n
    | None -> M.fail "item_storage_quantity" "the quantity does not read"
  in
  match Quantity_box.next_press ~now ~target ~most:stack with
  | None -> ()
  | Some _ when presses = 0 -> quantity_stuck now target
  | Some b ->
      steps.press b;
      set_quantity steps ~target ~stack (presses - 1)

(* From list row [cursor] (where {!scan} left it) UP or DOWN to the stack's
   row [k], which is then on the cursor's shown row. *)
let to_stack steps name ~cursor (k, count) =
  List.iter steps.press
    (List.init
       (abs (k - cursor))
       (fun _ -> if k < cursor then Wire.Up else Wire.Down));
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
      to_stack steps name ~cursor:stock.cursor stack;
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
let max_count_digits = 3
let cancel = "CANCEL"

let press_wait ms b =
  ignore (Effects.submit [ M.hold ~hold_ms ~cooldown_ms:ms b ])

let press b =
  match b with
  | Wire.A | Wire.B -> press_wait screen_ms b
  | _ -> press_wait menu_ms b

let looking f =
  Effects.with_probes (Pc_screen.probes @ Item_pc_screen.probes) (fun () ->
      match Effects.await ~timeout_ms:look_timeout_ms (fun _ -> true) with
      | Holds m -> Some (f m)
      | Timeout -> None)

let text line candidates =
  match Text.Line_reading.read (Text_data.glyphs ()) line candidates with
  | Read { text; _ } -> Some text
  | No_match _ -> None

(* The walk to WITHDRAW ITEM's list is Pc_box's, on the PC's and item
   storage's probes. *)
let open_withdraw ~log () =
  Effects.with_probes (Pc_screen.probes @ Item_pc_screen.probes) (fun () ->
      Pc_box.open_menu ~log Pc_box.screen_game_steps Withdraw_item)

let read_count row =
  Text.Number_reading.read_right_aligned
    ~max_score:Text.Number_reading.small_max_score
    (Text_data.small_glyphs ())
    (Text.Item_pc_lines.count_digit row)
    ~max_cells:max_count_digits

let read_row i name =
  match text (Text.Item_pc_lines.row i) [ name; cancel ] with
  | Some t when t = cancel -> Some Cancel
  | named -> (
      match read_count i with
      | Some count -> Some (Item { named = named = Some name; count })
      | None -> None)

let read_quantity () =
  Text.Number_reading.read_left_aligned
    ~max_score:Text.Number_reading.small_max_score
    (Text_data.small_glyphs ())
    Text.Item_pc_lines.quantity_digit ~max_cells:max_count_digits

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
    open_withdraw = open_withdraw ~log;
    read_row;
    cursor_row = (fun () -> Option.join (looking Item_pc_screen.cursor_row));
    press;
    await_quantity =
      (fun () ->
        await_on (fun m -> Item_pc_screen.quantity_shown m = Some true));
    read_quantity;
    close = close ~log;
  }

let item_name slug =
  let names =
    List.concat_map
      (Text.Item_names.in_pocket (Text_data.item_names ()))
      [ Items; Poke_balls; Tm_case; Berry_pouch ]
  in
  Bag_items.display_name names slug

let display_name ~where slug =
  match item_name slug with
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
        (fun (name, count) -> withdraw (screen_game_steps ~log) ~log name count)
    );
  ]
