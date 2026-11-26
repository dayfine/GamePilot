let panel_id = "save_dialog.panel"
let button_id = "save_dialog.button"
let time_id = "save_dialog.last_saved"
let panel : Native_box.t = { x = 260; y = 280; w = 1400; h = 14 }
let button : Native_box.t = { x = 640; y = 722; w = 640; h = 56 }

(* The whole "Last Saved" line short of Cancel: its label, date and time sit
   further right in French than in English. *)
let time : Native_box.t = { x = 258; y = 856; w = 1000; h = 32 }
let white = Color_count.white 200
let dark = Color_count.dark 110
let ink_max = 120

let ink =
  Wire.Line_shares.
    [
      { weights = (1, 0, 0); op = Less; value = ink_max };
      { weights = (0, 1, 0); op = Less; value = ink_max };
      { weights = (0, 0, 1); op = Less; value = ink_max };
    ]

let probes ~picture =
  Color_count.probe ~picture ~id:panel_id panel white
  @ Color_count.probe ~picture ~id:button_id button dark
  @ Pixel_shares.probe ~picture ~id:time_id time ink

let fraction m id = Option.value ~default:0. (Color_count.share m id)
let min_panel = 0.90
let min_button = 0.70

let shown m =
  fraction m panel_id > min_panel && fraction m button_id > min_button

let last_saved m =
  if not (shown m) then None
  else
    Option.map
      (fun (t : Wire.Line_shares.t) -> t.columns @ t.rows)
      (Pixel_shares.lines m time_id)

let max_change = 0.3

let same_time a b =
  List.length a = List.length b
  && List.fold_left2 (fun acc x y -> acc +. Float.abs (x -. y)) 0. a b
     <= max_change
