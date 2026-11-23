open Frlg_readers
module M = Menu_input
module Text = Frlg_text

let max_digits = 4
let reread_ms = 300

let read_coins () =
  Text.Number_reading.read_left_aligned (Text_data.glyphs ())
    Text.Text_lines.bag_message_digit ~max_cells:max_digits

let rec until_read deadline =
  match read_coins () with
  | Some coins -> Some coins
  | None when Effects.now () > deadline -> None
  | None ->
      ignore
        (Effects.submit [ Wire.Wait { wait_ms = reread_ms } ] : Wire.batch_done);
      until_read deadline

(* The item's own menu (USE, REGISTER, CANCEL) hides the pocket arrows; its
   box covers the list's frame, so the bag itself does not read either. *)
let item_menu m = Bag_screen.pocket m = None
let menu_ready_ms = 500

let read ~log =
  Bag_items.open_pocket_top Key_items;
  Bag_items.select "coin-case";
  M.press Wire.A;
  ignore (M.await_screen ~code:"no_item_menu" "the Coin Case's menu" item_menu);
  (* The menu has no cursor reader: USE, its top row, once it is drawn. *)
  ignore
    (Effects.submit [ Wire.Wait { wait_ms = menu_ready_ms } ] : Wire.batch_done);
  M.press Wire.A;
  let coins =
    until_read (Effects.now () +. float Trainer_card_money.read_timeout_ms)
  in
  log
    (match coins with
    | Some c -> Printf.sprintf "Coin Case: %d coins." c
    | None -> "Coin Case: the count did not read.");
  M.press Wire.B;
  M.close "the bag" Bag_screen.bag_open;
  M.settle_back ~label:"coin case" ~log;
  coins
