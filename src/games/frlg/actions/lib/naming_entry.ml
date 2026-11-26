open Frlg_readers
module M = Menu_input
module N = Naming_screen
module K = Frlg_text.Naming_keyboard

type game_steps = {
  read_page : unit -> N.page;
  read_key : N.page -> N.key option;
  read_cell : int -> string option;
  press : Wire.button -> unit;
}

let max_tries = 3
let box_name_chars = 8
let blank = " "
let repeat n b = List.init (max 0 n) (fun _ -> b)

let moves (from : N.key) (to_ : N.key) =
  let down = (to_.row - from.row + N.rows) mod N.rows in
  let vertical =
    if down <= N.rows / 2 then repeat down Wire.Down
    else repeat (N.rows - down) Wire.Up
  in
  let horizontal =
    if to_.col >= from.col then repeat (to_.col - from.col) Wire.Right
    else repeat (from.col - to_.col) Wire.Left
  in
  vertical @ horizontal

let page_name = function
  | N.Upper -> "capitals"
  | N.Lower -> "small letters"
  | N.Others -> "others"

(* SELECT until the page shows: at most twice, each to the next page. *)
let rec turn_to steps page target =
  if page = target then page
  else (
    steps.press Wire.Select;
    let now = steps.read_page () in
    if now <> K.next_page page then
      M.fail "naming_wrong_page"
        (Printf.sprintf "SELECT on the %s showed the %s" (page_name page)
           (page_name now));
    turn_to steps now target)

let key_name (k : N.key) =
  Printf.sprintf "row %d column %d" (k.row + 1) (k.col + 1)

(* Moves to the key, reading the cursor after each run of moves; off the
   button column with LEFT. *)
let rec reach steps page (target : N.key) tries =
  match steps.read_key page with
  | Some at when at = target -> ()
  | _ when tries = 0 ->
      M.fail "naming_no_cursor" ("the cursor did not reach " ^ key_name target)
  | Some at ->
      List.iter steps.press (moves at target);
      reach steps page target (tries - 1)
  | None ->
      steps.press Wire.Left;
      reach steps page target (tries - 1)

(* B until cell [i] is blank: the text is contiguous, so every cell after it
   is too. *)
let rec erase_to steps i tries =
  if steps.read_cell i = Some blank then ()
  else if tries = 0 then
    M.fail "naming_text_wrong" (Printf.sprintf "cell %d does not clear" (i + 1))
  else (
    steps.press Wire.B;
    erase_to steps i (tries - 1))

let cell_text = function
  | None -> "nothing"
  | Some c -> Printf.sprintf "\"%s\"" c

let position_of ~page c =
  match K.find ~on:page c with
  | Some p -> p
  | None ->
      M.fail ~repeats:true "bad_args"
        (Printf.sprintf "the keyboard has no \"%s\"" c)

(* Types character [c] into cell [i]; the page it ends on. *)
let rec type_char steps ~max_chars page i c tries =
  let pos = position_of ~page c in
  let page = turn_to steps page pos.page in
  reach steps page pos.key max_tries;
  steps.press Wire.A;
  let shown = steps.read_cell i in
  let extra = i + 1 < max_chars && steps.read_cell (i + 1) <> Some blank in
  if shown = Some c && not extra then page
  else if tries <= 1 then
    M.fail "naming_text_wrong"
      (Printf.sprintf "cell %d reads %s, not \"%s\"" (i + 1) (cell_text shown) c)
  else (
    erase_to steps i (max_chars - i);
    type_char steps ~max_chars page i c (tries - 1))

let check_args ~max_chars text =
  match K.chars text with
  | Error why -> M.fail ~repeats:true "bad_args" why
  | Ok cs when List.length cs > max_chars ->
      M.fail ~repeats:true "bad_args"
        (Printf.sprintf "\"%s\" is longer than %d characters" text max_chars)
  | Ok cs when List.for_all (fun c -> c = blank) cs ->
      M.fail ~repeats:true "bad_args"
        (Printf.sprintf "\"%s\" has no character but spaces" text)
  | Ok cs -> cs

let check_cell steps cs i =
  let want = Option.value (List.nth_opt cs i) ~default:blank in
  let shown = steps.read_cell i in
  if shown <> Some want then
    M.fail "naming_text_wrong"
      (Printf.sprintf "before OK, cell %d reads %s, not \"%s\"" (i + 1)
         (cell_text shown) want)

let check_all steps ~max_chars cs =
  List.iter (check_cell steps cs) (List.init max_chars Fun.id)

let type_text steps ~log ~max_chars text =
  let cs = check_args ~max_chars text in
  let page = steps.read_page () in
  ignore
    (List.fold_left
       (fun (page, i) c ->
         (type_char steps ~max_chars page i c max_tries, i + 1))
       (page, 0) cs
      : N.page * int);
  check_all steps ~max_chars cs;
  steps.press Wire.Start;
  steps.press Wire.A;
  log (Printf.sprintf "Naming screen: typed \"%s\" and OK." text)

(* Pacing measured on mGBA (BOX NAME?, 2026-11-25). *)
let hold_ms = 80
let tap_ms = 240
let key_ms = 400
let page_ms = 1000
let screen_timeout_ms = 2000

(* The cursor's red half shows about every half second. *)
let cursor_timeout_ms = 1500

let press b =
  let cooldown_ms =
    match b with
    | Wire.Up | Wire.Down | Wire.Left | Wire.Right -> tap_ms
    | Wire.Select -> page_ms
    | _ -> key_ms
  in
  ignore (Effects.submit [ M.hold ~hold_ms ~cooldown_ms b ])

let await_reading ~timeout_ms reader =
  Effects.with_probes N.probes (fun () ->
      match Effects.await ~timeout_ms (fun m -> reader m <> None) with
      | Holds m -> reader m
      | Timeout -> None)

let read_page () =
  match await_reading ~timeout_ms:screen_timeout_ms N.page with
  | Some p -> p
  | None -> M.fail "naming_no_page" "no keyboard page"

let read_key page = await_reading ~timeout_ms:cursor_timeout_ms (N.key page)

let read_cell ~max_chars i =
  match
    Frlg_text.Line_reading.read_preferring (Text_data.glyphs ())
      (Frlg_text.Text_lines.naming_entry_cell ~max_chars i)
      (List.filter (fun c -> c <> blank) K.charset)
      ~fallback:[ blank ]
  with
  | Read { text; _ } -> Some text
  | No_match _ -> None

let screen_game_steps ~max_chars =
  { read_page; read_key; read_cell = read_cell ~max_chars; press }
