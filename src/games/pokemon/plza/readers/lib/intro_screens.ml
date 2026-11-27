module Solid_color = Switch.Solid_color

let channels = 3.0
let brightness (s : Box_color.stats) = Solid_color.sum s.mean /. channels
let spread (s : Box_color.stats) = Solid_color.sum s.stddev

let fractions left top width height =
  Native_box.of_fractions { left; top; width; height }

let box (f : Native_box.fractions) = Native_box.of_fractions f

(* Every box's stats, or [None] when one is missing. *)
let read_all m ids =
  let stats = List.filter_map (Box_color.read m) ids in
  if List.length stats = List.length ids then Some stats else None

(* The language list. *)
type language_grid = {
  rows : int;
  left_column : float;
  right_column : float;
  first_row : float;
  row_step : float;
  strip_width : float;
  strip_height : float;
}

let lang_grid =
  {
    rows = 5;
    left_column = 0.2005;
    right_column = 0.5365;
    first_row = 0.331;
    row_step = 0.1;
    strip_width = 0.034;
    strip_height = 0.05;
  }

type language_colors = {
  gap_max_brightness : float;
  highlight_min : float;
  highlight_max_spread : float;
  slate_blue_over_red : float;
  slate_max_spread : float;
}

let lang_colors =
  {
    gap_max_brightness = 70.0;
    highlight_min = 200.0;
    highlight_max_spread = 30.0;
    slate_blue_over_red = 15.0;
    slate_max_spread = 20.0;
  }

let language_entries = 2 * lang_grid.rows

let language_strip i =
  fractions
    (if i < lang_grid.rows then lang_grid.left_column
     else lang_grid.right_column)
    (lang_grid.first_row
    +. (lang_grid.row_step *. float_of_int (i mod lang_grid.rows)))
    lang_grid.strip_width lang_grid.strip_height

let column_gap =
  box { left = 0.4896; top = 0.331; width = 0.0208; height = 0.447 }

let gap_id = "intro.language_gap"
let strip_id i = Printf.sprintf "intro.language%d" i
let strip_ids = List.init language_entries strip_id

type row = Highlighted | Plain | Other
type range = { lo : float; hi : float }

let between r v = v >= r.lo && v <= r.hi
let slate_red = { lo = 35.0; hi = 90.0 }
let slate_green = { lo = 45.0; hi = 110.0 }
let slate_blue = { lo = 65.0; hi = 140.0 }

(* classify_row with LANGUAGE_LIST_ROWS_SLATE. *)
let classify (s : Box_color.stats) =
  let m = s.mean in
  if
    m.r >= lang_colors.highlight_min
    && m.g >= lang_colors.highlight_min
    && m.b >= lang_colors.highlight_min
    && spread s <= lang_colors.highlight_max_spread
  then Highlighted
  else if
    between slate_red m.r && between slate_green m.g && between slate_blue m.b
    && m.b >= m.r +. lang_colors.slate_blue_over_red
    && spread s <= lang_colors.slate_max_spread
  then Plain
  else Other

(* highlighted_row: [None] on any other row, or on a second highlight. *)
let highlighted_row strips =
  let classes = List.map classify strips in
  let lit = List.filter (fun c -> c = Highlighted) classes in
  if List.mem Other classes || List.length lit > 1 then None
  else
    List.find_map
      (fun (i, c) -> if c = Highlighted then Some i else None)
      (List.mapi (fun i c -> (i, c)) classes)

let language_entry m =
  match (Box_color.read m gap_id, read_all m strip_ids) with
  | Some gap, Some strips when brightness gap < lang_colors.gap_max_brightness
    ->
      highlighted_row strips
  | _ -> None

(* The look picker. *)
type look_grid = {
  columns : int;
  first_tile_left : int;
  tile_step : int;
  top_row_top : int;
  bottom_row_top : int;
}

let lk_grid =
  {
    columns = 4;
    first_tile_left = 373;
    tile_step = 312;
    top_row_top = 324;
    bottom_row_top = 609;
  }

type corner_patch = { corners : int; near_in : int; far_in : int; size : int }

let patch = { corners = 4; near_in = 10; far_in = 218; size = 12 }
let face_offset : Native_box.t = { x = 90; y = 100; w = 60; h = 60 }

type corner_colors = {
  white_min : float;
  white_max_spread : float;
  dark_max_brightness : float;
  dark_max_red : float;
  dark_blue_over_red : float;
  dark_max_spread : float;
}

let corner_col =
  {
    white_min = 200.0;
    white_max_spread = 40.0;
    dark_max_brightness = 90.0;
    dark_max_red = 50.0;
    dark_blue_over_red = 20.0;
    dark_max_spread = 50.0;
  }

type face_thresholds = { min_brightness : float; min_spread : float }

let face_th = { min_brightness = 80.0; min_spread = 60.0 }
let looks = 2 * lk_grid.columns

let tile_left look =
  lk_grid.first_tile_left
  + (lk_grid.tile_step * ((look - 1) mod lk_grid.columns))

let tile_top look =
  if look <= lk_grid.columns then lk_grid.top_row_top
  else lk_grid.bottom_row_top

(* Corners 0 top left, 1 top right, 2 bottom left, 3 bottom right. *)
let corner_box look corner : Native_box.t =
  {
    x =
      (tile_left look + if corner mod 2 = 0 then patch.near_in else patch.far_in);
    y = (tile_top look + if corner < 2 then patch.near_in else patch.far_in);
    w = patch.size;
    h = patch.size;
  }

let face_box look : Native_box.t =
  {
    face_offset with
    x = tile_left look + face_offset.x;
    y = tile_top look + face_offset.y;
  }

let all_looks = List.init looks (fun i -> i + 1)
let corner_id look corner = Printf.sprintf "intro.look%d.corner%d" look corner
let face_id look = Printf.sprintf "intro.look%d.face" look

type corner = White | Dark | Neither

(* classify_look_corner. *)
let classify_corner (s : Box_color.stats) =
  let m = s.mean in
  if
    m.r >= corner_col.white_min
    && m.g >= corner_col.white_min
    && m.b >= corner_col.white_min
    && spread s <= corner_col.white_max_spread
  then White
  else if
    brightness s < corner_col.dark_max_brightness
    && m.r <= corner_col.dark_max_red
    && m.b >= m.r +. corner_col.dark_blue_over_red
    && spread s <= corner_col.dark_max_spread
  then Dark
  else Neither

let face_shows m look =
  match Box_color.read m (face_id look) with
  | Some s ->
      brightness s >= face_th.min_brightness && spread s >= face_th.min_spread
  | None -> false

(* look_white_corners: [None] when a corner is neither or no face shows. *)
let white_corners m look =
  let ids = List.init patch.corners (corner_id look) in
  match read_all m ids with
  | Some stats when face_shows m look ->
      let classes = List.map classify_corner stats in
      if List.mem Neither classes then None
      else Some (List.length (List.filter (fun c -> c = White) classes))
  | _ -> None

(* Each look's white corners, or [None] when one look does not read. *)
let look_corners m =
  let counts = List.map (white_corners m) all_looks in
  if List.mem None counts then None else Some (List.filter_map Fun.id counts)

let look_picker_shown m = Option.is_some (look_corners m)

(* The one look with white corners, when it has four. *)
let card counts =
  let lit = List.filter (fun (_, n) -> n > 0) (List.combine all_looks counts) in
  match lit with [ (look, n) ] when n = patch.corners -> Some look | _ -> None

let highlighted_look m = Option.bind (look_corners m) card

(* The name keyboard. *)
let question = box { left = 0.55; top = 0.05; width = 0.40; height = 0.12 }
let key_row = box { left = 0.03; top = 0.86; width = 0.80; height = 0.02 }
let dark_bar = box { left = 0.10; top = 0.935; width = 0.35; height = 0.03 }
let question_id = "intro.keyboard_question"
let key_row_id = "intro.keyboard_keys"
let bar_id = "intro.keyboard_bar"
let question_max_brightness = 40.0
let question_max_spread = 15.0
let keys_min_brightness = 185.0
let bar_brightness = { lo = 65.0; hi = 90.0 }
let bar_max_spread = 10.0

let light_keys m =
  match Box_color.read m key_row_id with
  | Some s -> brightness s >= keys_min_brightness
  | None -> false

let grey_bar m =
  match Box_color.read m bar_id with
  | Some s -> between bar_brightness (brightness s) && spread s < bar_max_spread
  | None -> false

let name_keyboard_shown m =
  match Box_color.read m question_id with
  | Some q
    when brightness q <= question_max_brightness
         && spread q <= question_max_spread ->
      light_keys m || grey_bar m
  | _ -> false

let language_probes ~picture =
  Box_color.probe ~picture ~id:gap_id column_gap
  @ List.concat
      (List.init language_entries (fun i ->
           Box_color.probe ~picture ~id:(strip_id i) (language_strip i)))

let look_probes ~picture look =
  Box_color.probe ~picture ~id:(face_id look) (face_box look)
  @ List.concat
      (List.init patch.corners (fun c ->
           Box_color.probe ~picture ~id:(corner_id look c) (corner_box look c)))

let keyboard_probes ~picture =
  List.concat_map
    (fun (id, b) -> Box_color.probe ~picture ~id b)
    [ (question_id, question); (key_row_id, key_row); (bar_id, dark_bar) ]

let probes ~picture =
  language_probes ~picture
  @ List.concat_map (look_probes ~picture) all_looks
  @ keyboard_probes ~picture
