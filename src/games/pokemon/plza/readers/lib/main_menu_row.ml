let rows = 6
let cards = 6

(* menu_row: row r's band is (0.06, 0.265 + 0.117 r - 0.025, 0.26, 0.05). *)
let first_row_centre = 0.265
let row_pitch = 0.117
let band_half = 0.025

let band r : Native_box.fractions =
  let centre = first_row_centre +. (row_pitch *. float_of_int r) in
  {
    left = 0.06;
    top = centre -. band_half;
    width = 0.26;
    height = 2. *. band_half;
  }

let band_id r = Printf.sprintf "main_menu_row.band%d" r
let white_min = 221
let white_floor = (white_min, white_min, white_min)
let channel_max = 255
let white_ceiling = (channel_max, channel_max, channel_max)

(* Card k's HP bar strip in frame pixels. *)
let first_card_x = 884
let card_pitch = 162

let bar k : Native_box.t =
  { x = first_card_x + (card_pitch * k); y = 394; w = 110; h = 12 }

let bar_id k = Printf.sprintf "main_menu_row.card%d" k

let green =
  Wire.Line_shares.
    [
      { weights = (0, 1, 0); op = Greater; value = 140 };
      { weights = (-1, 1, 0); op = Greater; value = 60 };
      { weights = (0, 1, -1); op = Greater; value = 60 };
    ]

let band_probe ~picture r =
  Option.map
    (fun box ->
      Wire.color_count_probe ~id:(band_id r) ~box ~delivery:Every
        ~min:white_floor ~max:white_ceiling)
    (Native_box.probe_box ~picture (Native_box.of_fractions (band r)))

let probes ~picture ~assets =
  Main_menu.probes ~picture ~assets
  @ List.filter_map (band_probe ~picture) (List.init rows Fun.id)
  @ List.concat_map
      (fun k -> Pixel_shares.probe ~picture ~id:(bar_id k) (bar k) green)
      (List.init cards Fun.id)

let fraction m id =
  match Effects.probe m id with
  | Some (Wire.Color_count { fraction; _ }) -> Some fraction
  | Some
      ( Wire.Color_stats _ | Wire.Template_match _ | Wire.Line_shares _
      | Wire.Find _ | Wire.Other _ )
  | None ->
      None

let white_shares m =
  List.init rows (fun r -> Option.value ~default:0. (fraction m (band_id r)))

let min_white = 0.45

(* The whitest band, with its share. *)
let whitest shares =
  List.fold_left
    (fun (best, top) (r, s) -> if s > top then (r, s) else (best, top))
    (0, 0.)
    (List.mapi (fun r s -> (r, s)) shares)

let highlighted m =
  let shares = List.init rows (fun r -> fraction m (band_id r)) in
  let best, share = whitest (List.map (Option.value ~default:0.) shares) in
  if (not (Main_menu.shown m)) || List.mem None shares || share <= min_white
  then None
  else Some best

let green_share m k =
  match Pixel_shares.lines m (bar_id k) with
  | Some { rows; _ } ->
      Option.value ~default:0.
        (Pixel_shares.window rows ~first:0 ~count:(List.length rows))
  | None -> 0.

let green_shares m = List.init cards (green_share m)
let min_green = 0.5
let max_empty_green = 0.05
let card_green m k = green_share m k >= min_green
let card_empty m k = green_share m k < max_empty_green
