open Frlg_readers
module Text = Frlg_text

let max_digits = 3

(* The count on the card's front once faded in, else none. *)
let look () =
  match Effects.read () with
  | Some m when Trainer_card_front.front_shown m ->
      Text.Number_reading.read_right_aligned (Text_data.glyphs ())
        Text.Text_lines.trainer_card_dex_digit ~max_cells:max_digits
  | _ -> None

let describe = Printf.sprintf "%d species caught"
let unread = "the Pokedex count did not read"
let read_with steps = Trainer_card_read.read_with steps ~describe ~unread
let read ~log = Trainer_card_read.read ~log ~look ~describe ~unread
