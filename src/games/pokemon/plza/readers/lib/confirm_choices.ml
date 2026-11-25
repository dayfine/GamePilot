let ready_row = 2

let rows : Native_box.t list =
  [
    { x = 620; y = 592; w = 100; h = 40 };
    { x = 620; y = 676; w = 100; h = 40 };
    { x = 620; y = 820; w = 100; h = 60 };
  ]

let background : Native_box.t list =
  [
    { x = 620; y = 742; w = 100; h = 40 }; { x = 770; y = 580; w = 30; h = 320 };
  ]

let row_id i = Printf.sprintf "confirm_choices.row%d" i
let background_id i = Printf.sprintf "confirm_choices.background%d" i

let probes ~picture =
  List.concat
    (List.mapi (fun i b -> Box_color.probe ~picture ~id:(row_id i) b) rows
    @ List.mapi
        (fun i b -> Box_color.probe ~picture ~id:(background_id i) b)
        background)

let sum (c : Wire.rgb) = c.r +. c.g +. c.b

(* confirm_background_dark's limits. *)
let dark_max_brightness = 90.0
let dark_max_spread = 80.0
let dark_max_red = 30.0
let dark_blue_over_red = 40.0

let dark (s : Box_color.stats) =
  sum s.mean /. 3.0 < dark_max_brightness
  && sum s.stddev <= dark_max_spread
  && s.mean.r <= dark_max_red
  && s.mean.b >= s.mean.r +. dark_blue_over_red

type row = Highlighted | Plain | Other

(* classify_row with CONFIRM_ROWS_SLATE, its slate bounds widened (see the
   .mli). *)
let highlight_min = 200.0
let max_spread = 30.0
let between lo hi v = v >= lo && v <= hi
let slate_blue_over_red = 15.0

let classify (s : Box_color.stats) =
  let m = s.mean and spread = sum s.stddev in
  if
    m.r >= highlight_min && m.g >= highlight_min && m.b >= highlight_min
    && spread <= max_spread
  then Highlighted
  else if
    between 10.0 65.0 m.r && between 30.0 90.0 m.g && between 50.0 125.0 m.b
    && m.b >= m.r +. slate_blue_over_red
    && spread <= max_spread
  then Plain
  else Other

(* Every box's stats, or [None] when one is missing. *)
let read_all m ids =
  let stats = List.filter_map (Box_color.read m) ids in
  if List.length stats = List.length ids then Some stats else None

let highlighted classes =
  let lit = List.filter (fun c -> c = Highlighted) classes in
  if List.mem Other classes || List.length lit <> 1 then None
  else
    List.find_map
      (fun (i, c) -> if c = Highlighted then Some i else None)
      (List.mapi (fun i c -> (i, c)) classes)

let read m =
  let back = read_all m (List.mapi (fun i _ -> background_id i) background) in
  let strips = read_all m (List.mapi (fun i _ -> row_id i) rows) in
  match (back, strips) with
  | Some back, Some strips when List.for_all dark back ->
      highlighted (List.map classify strips)
  | _ -> None
