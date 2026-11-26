module S = Steps
module L = Look

let button steps (l : L.t) =
  match l.choice_rows with
  | None ->
      S.(steps.log) "[PLZA scene] choice: rows not read: A";
      Wire.A
  | Some (selected, rows) when selected > 0 ->
      S.(steps.log)
        (Printf.sprintf
           "[PLZA scene] choice: %d rows, row %d highlighted: Up to row 0" rows
           selected);
      Wire.Up
  | Some (_, rows) ->
      S.(steps.log)
        (Printf.sprintf "[PLZA scene] choice: %d rows, row 0 highlighted: A"
           rows);
      Wire.A
