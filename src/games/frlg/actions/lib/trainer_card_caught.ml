open Frlg_readers
module Text = Frlg_text

let max_digits = 3
let reread_ms = 300

let read_count () =
  Text.Number_reading.read_right_aligned (Text_data.glyphs ())
    Text.Text_lines.trainer_card_dex_digit ~max_cells:max_digits

(* The count on the card's front once faded in, else none. *)
let look () =
  match Effects.read () with
  | Some m when Trainer_card_front.front_shown m -> read_count ()
  | _ -> None

let wait () =
  ignore
    (Effects.submit [ Wire.Wait { wait_ms = reread_ms } ] : Wire.batch_done)

(* A count stands once the next look agrees: the B that closes the card is lost
   while it still fades in (mGBA, 02-route10-new-species verification run 1). *)
let rec settled ~deadline previous =
  let count = look () in
  match (count, previous) with
  | Some n, Some before when n = before -> Some n
  | _ when Effects.now () > deadline -> None
  | _ ->
      wait ();
      settled ~deadline count

let read ~log =
  Menu_cursor.open_start_menu_row Trainer_card_money.player_row;
  let count =
    Effects.with_probes Trainer_card_front.probes (fun () ->
        settled
          ~deadline:(Effects.now () +. float Trainer_card_money.read_timeout_ms)
          None)
  in
  log
    (match count with
    | Some n -> Printf.sprintf "Trainer Card: %d species caught." n
    | None -> "Trainer Card: the Pokedex count did not read.");
  Trainer_card_money.close ~log;
  count
