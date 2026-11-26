module F = Frame_box
open Switch.Solid_color

type pane = Home_box | Game_box
type slot = { pane : pane; row : int; col : int }

let columns = 6
let slot_rows = 5

type templates = {
  slash : Effects.template_hash;
  digits : (int * Effects.template_hash) list;
}

let base = 10
let all_digits = List.init base Fun.id
let complete t = List.for_all (fun d -> List.mem_assoc d t.digits) all_digits

(* The counter. *)
let slash_id = "home.box.slash"
let counter : F.t = { x = 150; y = 780; w = 150; h = 34 }
let digits_left = 153
let advance = 17
let max_digits = 3
let window_slack = 4
let window_width = 26

let digit_box k : F.t =
  {
    x = digits_left + (advance * k) - window_slack;
    y = 780;
    w = window_width;
    h = 34;
  }

let digit_id k d = Printf.sprintf "home.box.digit%d.%d" k d
let ink_max = 170

let ink : Wire.color_range =
  { min = (0, 0, 0); max = (ink_max, ink_max, ink_max) }

(* Slots. *)
let frame_width = 1920.
let frame_height = 1080.
let home_left = 0.073
let game_left = 0.5635
let col_pitch = 0.0725
let first_row = 0.228
let row_pitch = 0.112
let slot_half = 28

let centre s =
  let left =
    match s.pane with Home_box -> home_left | Game_box -> game_left
  in
  ( Float.to_int (frame_width *. (left +. (col_pitch *. float_of_int s.col))),
    Float.to_int
      (frame_height *. (first_row +. (row_pitch *. float_of_int s.row))) )

let slot_box s : F.t =
  let cx, cy = centre s in
  {
    x = cx - slot_half;
    y = cy - slot_half;
    w = 2 * slot_half;
    h = 2 * slot_half;
  }

let pane_name = function Home_box -> "home" | Game_box -> "game"

let slot_id s =
  Printf.sprintf "home.slot.%s.%d.%d" (pane_name s.pane) s.row s.col

let cursor_id s =
  Printf.sprintf "home.cursor.%s.%d.%d" (pane_name s.pane) s.row s.col

let all_slots pane =
  List.init (columns * slot_rows) (fun i ->
      { pane; row = i / columns; col = i mod columns })

let probes t =
  F.template_probe ~ink slash_id counter t.slash
  :: List.concat_map
       (fun k ->
         List.map
           (fun (d, h) -> F.template_probe ~ink (digit_id k d) (digit_box k) h)
           t.digits)
       (List.init max_digits Fun.id)
  @ List.map
      (fun s -> F.stats_probe (slot_id s) (slot_box s))
      (all_slots Home_box @ all_slots Game_box)

(* The arrow's box over a slot. *)
let arrow_half = 25
let arrow_above = 112
let arrow_height = 54

let arrow_green =
  Wire.Line_shares.
    [
      { weights = (0, 1, 0); op = Greater; value = 150 };
      { weights = (-1, 1, 0); op = Greater; value = 60 };
      { weights = (0, 1, -1); op = Greater; value = 60 };
    ]

let arrow_box s : F.t =
  let cx, cy = centre s in
  {
    x = cx - arrow_half;
    y = cy - arrow_above;
    w = 2 * arrow_half;
    h = arrow_height;
  }

let cursor_probes s =
  Result.to_list
    (Wire.line_shares_probe ~id:(cursor_id s)
       ~box:(F.box (arrow_box s))
       ~delivery:Every ~test:arrow_green)

let max_slash_score = 0.1
let max_digit_score = 0.08

let shown m =
  Option.fold ~none:false
    ~some:(fun (score, _) -> score <= max_slash_score)
    (F.score m slash_id)

(* The best digit in window [k]: the lowest score, with it. *)
let best_digit m k =
  List.fold_left
    (fun best d ->
      match (F.score m (digit_id k d), best) with
      | Some (score, _), Some (_, top) when score >= top -> best
      | Some (score, _), _ -> Some (d, score)
      | None, _ -> best)
    None all_digits

let digit_count m =
  Option.map
    (fun (_, x) ->
      Float.to_int
        (Float.round ((x -. float_of_int digits_left) /. float_of_int advance)))
    (F.score m slash_id)

let read_digit m k =
  match best_digit m k with
  | Some (d, score) when score <= max_digit_score -> Some d
  | Some _ | None -> None

let digits_value digits =
  if List.mem None digits then None
  else
    Some
      (List.fold_left
         (fun v d -> (v * base) + Option.value ~default:0 d)
         0 digits)

let number m =
  match digit_count m with
  | Some n when shown m && n >= 1 && n <= max_digits ->
      digits_value (List.init n (read_digit m))
  | Some _ | None -> None

let counter_to_string m =
  let window k =
    Option.fold ~none:"-"
      ~some:(fun (d, score) -> Printf.sprintf "%d (%.3f)" d score)
      (best_digit m k)
  in
  Printf.sprintf "slash %s; digits %s"
    (Option.fold ~none:"-"
       ~some:(fun (score, x) -> Printf.sprintf "%.3f at x %.0f" score x)
       (F.score m slash_id))
    (String.concat ", " (List.map window (List.init max_digits Fun.id)))

let max_empty_stddev = 25.
let min_empty_sum = 550.

let empty m s =
  match stats m (slot_id s) with
  | Some st -> sum st.stddev <= max_empty_stddev && sum st.mean >= min_empty_sum
  | None -> false

let occupied m s = Option.is_some (stats m (slot_id s)) && not (empty m s)
let min_arrow = 0.15

let cursor_at m s =
  match Effects.probe m (cursor_id s) with
  | Some (Wire.Line_shares { rows; _ }) when rows <> [] ->
      List.fold_left ( +. ) 0. rows /. float_of_int (List.length rows)
      >= min_arrow
  | Some _ | None -> false

type order = Right_to_left | Left_to_right

let scan = function
  | Left_to_right -> List.init columns Fun.id
  | Right_to_left -> List.rev (List.init columns Fun.id)

let first_empty m order =
  List.find_opt (empty m)
    (List.concat_map
       (fun col ->
         List.init slot_rows (fun row -> { pane = Home_box; row; col }))
       (scan order))

let place_to_string s = Printf.sprintf "row %d column %d" (s.row + 1) (s.col + 1)

let slot_to_string s =
  Printf.sprintf "%s box row %d column %d"
    (match s.pane with Home_box -> "HOME's" | Game_box -> "the game's")
    (s.row + 1) (s.col + 1)
