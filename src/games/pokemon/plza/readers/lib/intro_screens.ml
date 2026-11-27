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
let list_rows = 5
let language_entries = 2 * list_rows
let left_column = 0.2005
let right_column = 0.5365
let first_row = 0.331
let row_step = 0.1
let strip_width = 0.034
let strip_height = 0.05

let language_strip i =
  fractions
    (if i < list_rows then left_column else right_column)
    (first_row +. (row_step *. float_of_int (i mod list_rows)))
    strip_width strip_height

let column_gap =
  box { left = 0.4896; top = 0.331; width = 0.0208; height = 0.447 }

let gap_id = "intro.language_gap"
let strip_id i = Printf.sprintf "intro.language%d" i
let strip_ids = List.init language_entries strip_id
let gap_max_brightness = 70.0

type row = Highlighted | Plain | Other

let highlight_min = 200.0
let highlight_max_spread = 30.0

type range = { lo : float; hi : float }

let between r v = v >= r.lo && v <= r.hi
let slate_red = { lo = 35.0; hi = 90.0 }
let slate_green = { lo = 45.0; hi = 110.0 }
let slate_blue = { lo = 65.0; hi = 140.0 }
let slate_blue_over_red = 15.0
let slate_max_spread = 20.0

(* classify_row with LANGUAGE_LIST_ROWS_SLATE. *)
let classify (s : Box_color.stats) =
  let m = s.mean in
  if
    m.r >= highlight_min && m.g >= highlight_min && m.b >= highlight_min
    && spread s <= highlight_max_spread
  then Highlighted
  else if
    between slate_red m.r && between slate_green m.g && between slate_blue m.b
    && m.b >= m.r +. slate_blue_over_red
    && spread s <= slate_max_spread
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
  | Some gap, Some strips when brightness gap < gap_max_brightness ->
      highlighted_row strips
  | _ -> None

(* The look picker. *)
let look_columns = 4
let looks = 2 * look_columns
let first_tile_left = 373
let tile_step = 312
let top_row_top = 324
let bottom_row_top = 609

let tile_left look =
  first_tile_left + (tile_step * ((look - 1) mod look_columns))

let tile_top look = if look <= look_columns then top_row_top else bottom_row_top
let patch_in = 10
let far_patch_in = 218
let patch = 12

(* Corners 0 top left, 1 top right, 2 bottom left, 3 bottom right. *)
let corner_box look corner : Native_box.t =
  {
    x = (tile_left look + if corner mod 2 = 0 then patch_in else far_patch_in);
    y = (tile_top look + if corner < 2 then patch_in else far_patch_in);
    w = patch;
    h = patch;
  }

let face_dx = 90
let face_dy = 100
let face_size = 60

let face_box look : Native_box.t =
  {
    x = tile_left look + face_dx;
    y = tile_top look + face_dy;
    w = face_size;
    h = face_size;
  }

let corners = 4
let all_looks = List.init looks (fun i -> i + 1)
let corner_id look corner = Printf.sprintf "intro.look%d.corner%d" look corner
let face_id look = Printf.sprintf "intro.look%d.face" look

type corner = White | Dark | Neither

let white_min = 200.0
let white_max_spread = 40.0
let dark_max_brightness = 90.0
let dark_max_red = 50.0
let dark_blue_over_red = 20.0
let dark_max_spread = 50.0

(* classify_look_corner. *)
let classify_corner (s : Box_color.stats) =
  let m = s.mean in
  if
    m.r >= white_min && m.g >= white_min && m.b >= white_min
    && spread s <= white_max_spread
  then White
  else if
    brightness s < dark_max_brightness
    && m.r <= dark_max_red
    && m.b >= m.r +. dark_blue_over_red
    && spread s <= dark_max_spread
  then Dark
  else Neither

let face_min_brightness = 80.0
let face_min_spread = 60.0

let face_shows m look =
  match Box_color.read m (face_id look) with
  | Some s -> brightness s >= face_min_brightness && spread s >= face_min_spread
  | None -> false

(* look_white_corners: [None] when a corner is neither or no face shows. *)
let white_corners m look =
  let ids = List.init corners (corner_id look) in
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
  match lit with [ (look, n) ] when n = corners -> Some look | _ -> None

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
      (List.init corners (fun c ->
           Box_color.probe ~picture ~id:(corner_id look c) (corner_box look c)))

let keyboard_probes ~picture =
  List.concat_map
    (fun (id, b) -> Box_color.probe ~picture ~id b)
    [ (question_id, question); (key_row_id, key_row); (bar_id, dark_bar) ]

let probes ~picture =
  language_probes ~picture
  @ List.concat_map (look_probes ~picture) all_looks
  @ keyboard_probes ~picture
