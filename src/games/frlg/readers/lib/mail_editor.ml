let yes_box : Wire.box =
  { x = 0.7289230769; y = 0.4604230588; w = 0.029; h = 0.076 }

(* SelectionArrowPositionConfirmationMenu's NO box is this far below YES. *)
let no_offset = 0.0875
let no_box : Wire.box = { yes_box with y = yes_box.y +. no_offset }
let arrow = Cursor_column.make ~prefix:"mail_editor.yes_no" [ yes_box; no_box ]
let probes = Cursor_column.probes arrow

let confirm_arrow m =
  match Cursor_column.row arrow m with
  | Some 0 -> Some true
  | Some _ -> Some false
  | None -> None
