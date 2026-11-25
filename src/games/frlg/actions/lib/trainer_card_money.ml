open Frlg_readers
module M = Menu_input
module Text = Frlg_text

let player_row = 3
let max_digits = 6
let read_timeout_ms = 6000
let reread_ms = 300

let read_money () =
  Text.Number_reading.read_right_aligned (Text_data.glyphs ())
    Text.Text_lines.trainer_card_money_digit ~max_cells:max_digits

let rec until_read deadline =
  match read_money () with
  | Some money -> Some money
  | None when Effects.now () > deadline -> None
  | None ->
      ignore
        (Effects.submit [ Wire.Wait { wait_ms = reread_ms } ] : Wire.batch_done);
      until_read deadline

let close ~log =
  M.press Wire.B;
  ignore
    (M.await_screen ~timeout_ms:read_timeout_ms ~code:"not_closed"
       "the Start menu after the card" Start_menu.start_menu_open);
  M.close "the Start menu" Start_menu.start_menu_open;
  M.settle_back ~label:"trainer card" ~log

let read ~log =
  Menu_cursor.open_start_menu_row player_row;
  let money = until_read (Effects.now () +. float read_timeout_ms) in
  log
    (match money with
    | Some m -> Printf.sprintf "Trainer Card: money $%d." m
    | None -> "Trainer Card: the money did not read.");
  close ~log;
  money
