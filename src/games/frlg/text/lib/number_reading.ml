let digit_count = 10
let digits = List.init digit_count string_of_int

let read_cells glyphs cell ~max_cells =
  let rec from k =
    if k >= max_cells then []
    else
      match Line_reading.read glyphs (cell k) digits with
      | Read { text; _ } -> text :: from (k + 1)
      | No_match _ -> []
  in
  from 0

let number = function
  | [] -> None
  | read -> int_of_string_opt (String.concat "" read)

let read_left_aligned glyphs cell ~max_cells =
  number (read_cells glyphs cell ~max_cells)

let read_right_aligned glyphs cell ~max_cells =
  number (List.rev (read_cells glyphs cell ~max_cells))
