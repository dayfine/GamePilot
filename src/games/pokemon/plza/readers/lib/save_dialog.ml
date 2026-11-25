let panel_id = "save_dialog.panel"
let button_id = "save_dialog.button"
let time_id = "save_dialog.last_saved"
let panel : Native_box.t = { x = 260; y = 280; w = 1400; h = 14 }
let button : Native_box.t = { x = 640; y = 722; w = 640; h = 56 }
let time : Native_box.t = { x = 552; y = 856; w = 70; h = 32 }
let white_min = 200
let dark_max = 110
let ink_max = 120
let channel_max = 255

let count ~picture id box (min, max) =
  Option.map
    (fun box -> Wire.color_count_probe ~id ~box ~delivery:Every ~min ~max)
    (Native_box.probe_box ~picture box)

let ink =
  Wire.Line_shares.
    [
      { weights = (1, 0, 0); op = Less; value = ink_max };
      { weights = (0, 1, 0); op = Less; value = ink_max };
      { weights = (0, 0, 1); op = Less; value = ink_max };
    ]

let probes ~picture =
  List.filter_map Fun.id
    [
      count ~picture panel_id panel
        ( (white_min, white_min, white_min),
          (channel_max, channel_max, channel_max) );
      count ~picture button_id button ((0, 0, 0), (dark_max, dark_max, dark_max));
    ]
  @ Pixel_shares.probe ~picture ~id:time_id time ink

let fraction m id =
  match Effects.probe m id with
  | Some (Wire.Color_count { fraction; _ }) -> fraction
  | Some
      ( Wire.Color_stats _ | Wire.Template_match _ | Wire.Line_shares _
      | Wire.Find _ | Wire.Other _ )
  | None ->
      0.

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
