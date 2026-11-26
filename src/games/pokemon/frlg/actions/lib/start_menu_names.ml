module Text = Frlg_text

let names = [ "POKéDEX"; "POKéMON"; "BAG"; "SAVE"; "OPTION"; "EXIT"; "RETIRE" ]
let rows = 7

let read_row i =
  match
    Text.Line_reading.read (Text_data.glyphs ())
      (Text.Text_lines.start_menu_row i)
      names
  with
  | Read { text; _ } -> Some text
  | No_match _ -> None

let read_rows () = List.init rows read_row

let row_of name rows =
  let rec find i = function
    | [] -> None
    | Some n :: _ when n = name -> Some i
    | _ :: rest -> find (i + 1) rest
  in
  find 0 rows
