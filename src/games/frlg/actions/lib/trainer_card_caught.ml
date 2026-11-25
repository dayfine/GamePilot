module Text = Frlg_text

let max_digits = 3
let reread_ms = 300

let read_count () =
  Text.Number_reading.read_right_aligned (Text_data.glyphs ())
    Text.Text_lines.trainer_card_dex_digit ~max_cells:max_digits

let rec until_read deadline =
  match read_count () with
  | Some count -> Some count
  | None when Effects.now () > deadline -> None
  | None ->
      ignore
        (Effects.submit [ Wire.Wait { wait_ms = reread_ms } ] : Wire.batch_done);
      until_read deadline

let read ~log =
  Menu_cursor.open_start_menu_row Trainer_card_money.player_row;
  let count =
    until_read (Effects.now () +. float Trainer_card_money.read_timeout_ms)
  in
  log
    (match count with
    | Some n -> Printf.sprintf "Trainer Card: %d species caught." n
    | None -> "Trainer Card: the Pokedex count did not read.");
  Trainer_card_money.close ~log;
  count
