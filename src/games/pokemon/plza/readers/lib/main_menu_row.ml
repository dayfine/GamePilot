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
let white = Color_count.white white_min

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
  Color_count.probe ~picture ~id:(band_id r)
    (Native_box.of_fractions (band r))
    white

(* The sixth row's button: its left and right edges (x 96 and 672 of the
   1080p frame) in a strip above its name (y 870 to 896), each read 8 px
   inside and 8 px outside, 4 px off the edge. *)
let edge_top = 870
let edge_height = 26
let edge_width = 8
let left_edge = 96
let right_edge = 672
let edge_gap = 4

let edge_box x : Native_box.t =
  { x; y = edge_top; w = edge_width; h = edge_height }

let edges =
  [
    ("left_outside", left_edge - edge_gap - edge_width);
    ("left_inside", left_edge + edge_gap);
    ("right_inside", right_edge - edge_gap - edge_width);
    ("right_outside", right_edge + edge_gap);
  ]

let edge_id name = "main_menu_row.link_play_" ^ name

let link_play_probes ~picture =
  List.concat_map (band_probe ~picture) (List.init rows Fun.id)
  @ List.concat_map
      (fun (name, x) ->
        Box_color.probe ~picture ~id:(edge_id name) (edge_box x))
      edges

let probes ~picture ~assets =
  Main_menu.probes ~picture ~assets
  @ link_play_probes ~picture
  @ List.concat_map
      (fun k -> Pixel_shares.probe ~picture ~id:(bar_id k) (bar k) green)
      (List.init cards Fun.id)

let fraction = Color_count.share

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

let channels = 3.

(* A box's brightness: its mean's channels averaged. *)
let brightness m name =
  Option.map
    (fun (s : Box_color.stats) ->
      Switch_home.Solid_color.sum s.mean /. channels)
    (Box_color.read m (edge_id name))

let link_play_step m =
  match List.map (fun (name, _) -> brightness m name) edges with
  | [ Some left_out; Some left_in; Some right_in; Some right_out ] ->
      Some ((left_in -. left_out +. (right_in -. right_out)) /. 2.)
  | _ -> None

let min_link_play_step = 13.

let link_play_shown m =
  highlighted m <> None
  &&
  match link_play_step m with
  | Some step -> step >= min_link_play_step
  | None -> false

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
