module L = Wire.Line_shares

type key = { row : int; col : int }

let first_key = { row = 0; col = 0 }

(* The keys by row and column: '.' a disabled key. *)
let layout = [| "1234567890"; "QWERTYU..P"; "ASDFGHJKL."; ".XCVBNM..." |]
let disabled = '.'
let enabled { row; col } = layout.(row).[col] <> disabled

let key_of_char ch =
  let ch = Char.uppercase_ascii ch in
  let in_row row =
    Option.map (fun col -> { row; col }) (String.index_opt layout.(row) ch)
  in
  if ch = disabled then None
  else List.find_map in_row (List.init (Array.length layout) Fun.id)

let normalize code =
  String.uppercase_ascii code
  |> String.to_seq
  |> Seq.filter (fun ch -> ch <> ' ' && ch <> '-')
  |> String.of_seq

let steps n (forward, back) =
  List.init (abs n) (fun _ -> if n > 0 then forward else back)

let across n = steps n (Wire.Right, Wire.Left)
let down n = steps n (Wire.Down, Wire.Up)

(* The keys from [a] to [b] inclusive, either way. *)
let span a b =
  List.init (abs (b - a) + 1) (fun i -> if b >= a then a + i else a - i)

(* clear_h_then_v: along the row, then down the target's column, no disabled
   key. *)
let clear_row_then_column from target =
  List.for_all
    (fun col -> enabled { row = from.row; col })
    (span from.col target.col)
  && List.for_all
       (fun row -> enabled { row; col = target.col })
       (span from.row target.row)

let moves from target =
  let dc = target.col - from.col and dr = target.row - from.row in
  if dr = 0 || dc = 0 || clear_row_then_column from target then
    across dc @ down dr
  else down dr @ across dc

let key_for ch =
  Option.to_result
    ~none:(Printf.sprintf "no enabled key types %C" ch)
    (key_of_char ch)

(* The keys of the code, or the first character without one. *)
let keys code =
  let add acc ch =
    Result.bind acc (fun ks -> Result.map (fun k -> k :: ks) (key_for ch))
  in
  Result.map List.rev
    (Seq.fold_left add (Ok []) (String.to_seq (normalize code)))

(* Each key's moves from the one before, and A. *)
let key_presses from targets =
  let step (at, acc) target = (target, acc @ moves at target @ [ Wire.A ]) in
  snd (List.fold_left step (from, []) targets)

let presses ~from code = Result.map (key_presses from) (keys code)

(* The probes, in frame pixels. *)
type geometry = {
  frame_width : float;
  frame_height : float;
  first_column : float;
  column_step : float;
  character_columns : float;
  cursor_top : float;
  cursor_bottom : float;
}

let geom =
  {
    frame_width = 1920.;
    frame_height = 1080.;
    first_column = 0.077;
    column_step = 0.075;
    character_columns = 11.;
    cursor_top = 0.43;
    cursor_bottom = 0.8145;
  }

let keys_id = "code_keyboard.keys_dark"
let light_keys_id = "code_keyboard.keys_light"
let cursor_id = "code_keyboard.cursor"
let keys_box : Wire.box = { x = 0.10; y = 0.50; w = 0.70; h = 0.35 }

(* The fork's KEY_ROW_Y, KEY_COL_X0 and KEY_COL_STEP; the cursor box spans the
   first four rows (to halfway to the bottom row, above PAGE_LABELS) and the
   eleven character columns (to halfway to the right column). *)
type row_ys = { digit : float; top : float; middle : float; bottom : float }

let rows = { digit = 0.500; top = 0.593; middle = 0.681; bottom = 0.770 }
let key_rows = [ rows.digit; rows.top; rows.middle; rows.bottom ]

let cursor_box : Wire.box =
  {
    x = 0.;
    y = geom.cursor_top;
    w =
      geom.first_column +. ((geom.character_columns -. 0.5) *. geom.column_step);
    h = geom.cursor_bottom -. geom.cursor_top;
  }

type luma_bounds = {
  neutral_within : int;
  dark_low : int;
  dark_high : int;
  light_low : int;
  light_high : int;
}

let luma =
  {
    neutral_within = 15;
    dark_low = 40;
    dark_high = 135;
    light_low = 200;
    light_high = 250;
  }

let neutral =
  L.
    [
      { weights = (1, -1, 0); op = Less; value = luma.neutral_within };
      { weights = (-1, 1, 0); op = Less; value = luma.neutral_within };
      { weights = (0, 1, -1); op = Less; value = luma.neutral_within };
      { weights = (0, -1, 1); op = Less; value = luma.neutral_within };
    ]

let between low high =
  L.
    [
      { weights = (1, 0, 0); op = Greater; value = low };
      { weights = (1, 0, 0); op = Less; value = high };
    ]

(* is_cursor_pixel. *)
let cursor_test =
  L.
    [
      { weights = (1, 0, 0); op = Less; value = 130 };
      { weights = (0, 1, 0); op = Greater; value = 160 };
      { weights = (0, 0, 1); op = Greater; value = 170 };
      { weights = (-1, 1, 0); op = Greater; value = 60 };
    ]

let probes =
  List.filter_map Result.to_option
    [
      Wire.line_shares_probe ~id:keys_id ~box:keys_box ~delivery:Every
        ~test:(neutral @ between luma.dark_low luma.dark_high);
      Wire.line_shares_probe ~id:light_keys_id ~box:keys_box ~delivery:Every
        ~test:(neutral @ between luma.light_low luma.light_high);
      Wire.line_shares_probe ~id:cursor_id ~box:cursor_box ~delivery:Every
        ~test:cursor_test;
    ]

let lines m id =
  match Effects.probe m id with
  | Some (Wire.Line_shares t) -> Some t
  | _ -> None

let mean = function
  | [] -> 0.
  | xs -> List.fold_left ( +. ) 0. xs /. float_of_int (List.length xs)

let share m id =
  Option.fold ~none:0. ~some:(fun (t : L.t) -> mean t.rows) (lines m id)

let min_keys_share = 0.55

let grey_keys m =
  share m keys_id > min_keys_share || share m light_keys_id > min_keys_share

(* The weighted mean position of the lines' shares, 0..1 along the box. *)
let centroid shares =
  let total = List.fold_left ( +. ) 0. shares in
  let n = float_of_int (List.length shares) in
  let moment =
    List.fold_left ( +. ) 0.
      (List.mapi (fun i s -> s *. (float_of_int i +. 0.5)) shares)
  in
  if total <= 0. then None else Some (moment /. total /. n)

let nearest_row y =
  let distance i = Float.abs (List.nth key_rows i -. y) in
  List.fold_left
    (fun best i -> if distance i < distance best then i else best)
    0
    (List.init (List.length key_rows) Fun.id)

let min_cursor_share = 0.0005

let key_at x y =
  let col =
    Float.to_int (Float.round ((x -. geom.first_column) /. geom.column_step))
  in
  if col < 0 || col >= String.length layout.(0) then None
  else Some { row = nearest_row y; col }

let enough_cyan (t : L.t) =
  let width = float_of_int (List.length t.columns) in
  List.fold_left ( +. ) 0. t.rows *. width
  >= min_cursor_share *. geom.frame_width *. geom.frame_height

let cursor_key (t : L.t) =
  match (centroid t.columns, centroid t.rows) with
  | Some cx, Some cy when enough_cyan t ->
      key_at
        (cursor_box.x +. (cx *. cursor_box.w))
        (cursor_box.y +. (cy *. cursor_box.h))
  | _ -> None

let cursor m = Option.bind (lines m cursor_id) cursor_key
let shown m = grey_keys m && cursor m <> None

(* The presses: D-pad 80 ms then 140, A 80 then 180. *)
let move_hold_ms = 80
let move_cooldown_ms = 140
let a_hold_ms = 80
let a_cooldown_ms = 180

let press button : Timed_press.t =
  if button = Wire.A then
    { button; hold_ms = a_hold_ms; cooldown_ms = a_cooldown_ms }
  else { button; hold_ms = move_hold_ms; cooldown_ms = move_cooldown_ms }

let start_key ~log m =
  match cursor m with
  | Some k ->
      log (Printf.sprintf "Keyboard cursor on %c." layout.(k.row).[k.col]);
      k
  | None ->
      log "No keyboard cursor read; starting from \"1\".";
      first_key

let type_on ~log code m =
  if not (shown m) then Error "the keyboard is not open"
  else
    Result.map
      (fun buttons ->
        log (Printf.sprintf "Typing %s." (normalize code));
        Timed_press.press_all (List.map press buttons))
      (presses ~from:(start_key ~log m) code)

let read_wait_ms = 1000

let type_code ~log ~picture code =
  if not (Picture_box.native picture) then
    Error
      "the keyboard is read on the whole frame: run the daemon with --viewport \
       native"
  else
    Effects.with_probes probes (fun () ->
        match Effects.await ~timeout_ms:read_wait_ms shown with
        | Timeout -> Error "the keyboard is not open"
        | Holds m -> type_on ~log code m)
