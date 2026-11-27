module K = Code_keyboard

type game_steps = {
  read_cursor : unit -> K.key option;
  read_text_pixels : unit -> int;
  submit : Wire.command list -> unit;
  log : string -> unit;
}

(* KEYBOARD_POSITIONS_QWERTY. *)
let layout = [| "1234567890-"; "QWERTYUIOP/"; "ASDFGHJKL:'"; "ZXCVBNM,.?!" |]

let key_of_char ch =
  let ch = Char.uppercase_ascii ch in
  List.find_map
    (fun row ->
      Option.map (fun col -> { K.row; col }) (String.index_opt layout.(row) ch))
    (List.init (Array.length layout) Fun.id)

let missing text =
  String.to_seq text
  |> Seq.filter (fun ch -> key_of_char ch = None)
  |> String.of_seq

type move = { button : Wire.button; wraps : bool }

(* keyboard_get_path: the twelve columns are a ring; a move past either side
   wraps. *)
let ring = 12
let short_way = 6

let vertical (from : K.key) (target : K.key) =
  let n = target.row - from.row in
  List.init (abs n) (fun _ ->
      { button = (if n > 0 then Wire.Down else Wire.Up); wraps = false })

let rec horizontal col target acc =
  if col = target then List.rev acc
  else
    let right =
      if target > col then target - col <= short_way
      else col - target > short_way
    in
    let next = if right then col + 1 else col - 1 in
    let wraps = next < 0 || next >= ring in
    let move = { button = (if right then Wire.Right else Wire.Left); wraps } in
    horizontal ((next + ring) mod ring) target (move :: acc)

let path ~(from : K.key) (target : K.key) =
  vertical from target @ horizontal from.col target.col []

(* The fork's delays, and button_hold: the Switch 1 code entry hold (two of
   its 40 ms units). *)
let hold_ms = 80
let move_release_ms = 200
let wrap_release_ms = 400
let settle_ms = 300
let shift_release_ms = 250
let key_release_ms = 300
let max_move_tries = 10
let max_field_reads = 3
let min_character_pixels = 10
let press button release = Wire.press ~hold_ms ~cooldown_ms:release [ button ]
let settle steps = steps.submit [ Wire.Wait { wait_ms = settle_ms } ]

let move_letter { button; wraps } =
  let letter =
    match button with
    | Wire.Up -> "U"
    | Wire.Right -> "R"
    | Wire.Down -> "D"
    | Wire.Left -> "L"
    | b -> Wire.string_of_button b
  in
  if wraps then letter ^ "*" else letter

let moves_text moves = String.concat "" (List.map move_letter moves)

let move_command m =
  press m.button (if m.wraps then wrap_release_ms else move_release_ms)

let cursor_failure (last : K.key option) (target : K.key) ch =
  let where =
    match last with
    | Some k ->
        Printf.sprintf "the cursor is at (%d, %d), not on '%c' at (%d, %d)"
          k.row k.col ch target.row target.col
    | None ->
        Printf.sprintf
          "the cursor could not be read while moving to '%c' at (%d, %d)" ch
          target.row target.col
  in
  Printf.sprintf "System keyboard: %s, after %d tries." where max_move_tries

let step_toward steps (cursor : K.key) (target : K.key) ch attempt =
  let moves = path ~from:cursor target in
  steps.log
    (Printf.sprintf
       "System keyboard: cursor (%d, %d) -> '%c' (%d, %d): %s, try %d."
       cursor.row cursor.col ch target.row target.col (moves_text moves)
       (attempt + 1));
  steps.submit (List.map move_command moves);
  settle steps

let no_cursor steps attempt =
  steps.log
    (Printf.sprintf "System keyboard: no cursor seen, try %d." (attempt + 1));
  settle steps

let rec move_cursor steps (target : K.key) ch ~last attempt =
  if attempt >= max_move_tries then Error (cursor_failure last target ch)
  else
    match steps.read_cursor () with
    | None ->
        no_cursor steps attempt;
        move_cursor steps target ch ~last (attempt + 1)
    | Some k when k = target -> Ok ()
    | Some k ->
        step_toward steps k target ch attempt;
        move_cursor steps target ch ~last:(Some k) (attempt + 1)

let rec field_grew steps ~before read =
  let after = steps.read_text_pixels () in
  if after >= before + min_character_pixels then Ok ()
  else if read + 1 >= max_field_reads then Error after
  else (
    settle steps;
    field_grew steps ~before (read + 1))

let is_upper ch = ch >= 'A' && ch <= 'Z'

let press_key steps ch =
  let before = steps.read_text_pixels () in
  let shift =
    if is_upper ch then [ press Wire.LStick shift_release_ms ] else []
  in
  steps.submit (shift @ [ press Wire.A key_release_ms ]);
  Result.map_error
    (fun after ->
      Printf.sprintf
        "System keyboard: pressed '%c', but the text field did not change (%d \
         -> %d white pixels)."
        ch before after)
    (field_grew steps ~before 0)

let type_char steps ch =
  match key_of_char ch with
  | None -> Error (Printf.sprintf "System keyboard: no key types '%c'." ch)
  | Some target ->
      Result.bind (move_cursor steps target ch ~last:None 0) (fun () ->
          press_key steps ch)

let type_each steps acc ch = Result.bind acc (fun () -> type_char steps ch)

let no_key text chars =
  Printf.sprintf
    "System keyboard: \"%s\" has characters with no key on the keyboard: \
     \"%s\"."
    text chars

let type_text steps text =
  match missing text with
  | "" -> String.fold_left (type_each steps) (Ok ()) text
  | chars -> Error (no_key text chars)

(* system_keyboard_text_pixels' field, in frame fractions. *)
let field_box : Wire.box = { x = 0.03; y = 0.17; w = 0.87; h = 0.105 }
let text_id = "keyboard_typing.text"
let white_above = 191
let max_channel = 255
let frame_width = 1920.
let frame_height = 1080.

let probes =
  K.probes
  @ [
      Wire.color_count_probe ~id:text_id ~box:field_box ~delivery:Every
        ~min:(white_above, white_above, white_above)
        ~max:(max_channel, max_channel, max_channel);
    ]

let field_pixels = field_box.w *. frame_width *. field_box.h *. frame_height

let text_pixels m =
  match Effects.probe m text_id with
  | Some (Wire.Color_count { fraction; _ }) ->
      Float.to_int (Float.round (fraction *. field_pixels))
  | Some
      ( Wire.Color_stats _ | Wire.Template_match _ | Wire.Template_ncc _
      | Wire.Line_shares _ | Wire.Find _ | Wire.Other _ )
  | None ->
      0
