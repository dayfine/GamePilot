open Frlg_readers
module M = Menu_input
module Text = Frlg_text
module Words = Text.Easy_chat_words

type word = { group : string; word : string }

let max_rows = 130
let hold_ms = 100

(* After a cursor move: a list row scrolls in. Measured on mGBA: presses 333
   ms apart all landed, through 30 rows of MOVE 1. *)
let move_ms = 350

(* After A: the grid or the list opens, or the word lands in its field. *)
let open_ms = 800
let cursor_timeout_ms = 2000
let group_width = 76
let word_width = 88
let unknown = Text.Mail_fields.unknown_word
let field_row i = i / 2
let field_col i = i mod 2

let moves_to_next_field i =
  if field_col i = 0 then [ Wire.Right ] else [ Wire.Down; Wire.Left ]

let press ms b = ignore (Effects.submit [ M.hold ~hold_ms ~cooldown_ms:ms b ])

let words () =
  match Text.Data_files.locate Text.Data_files.easy_chat_words_eng with
  | None -> M.fail ~repeats:true "no_text_data" "the Easy Chat words not found"
  | Some file -> (
      match Words.load file with
      | Ok w -> w
      | Error why -> M.fail ~repeats:true "no_text_data" why)

let read_cell line candidates =
  match Text.Line_reading.read (Text_data.glyphs ()) line candidates with
  | Read { text; _ } -> Some text
  | No_match _ -> None

let no_cursor what = M.fail "easy_chat_no_cursor" ("no cursor on the " ^ what)

let cursor what reader =
  Effects.with_probes Easy_chat_screen.probes (fun () ->
      match
        Effects.await ~timeout_ms:cursor_timeout_ms (fun m -> reader m <> None)
      with
      | Holds m -> ( match reader m with Some c -> c | None -> no_cursor what)
      | Timeout -> no_cursor what)

type game_steps = {
  read_cursor : unit -> Easy_chat_screen.cell;
  read_cell : row:int -> col:int -> string option;
  press : Wire.button -> unit;
}

let column_of steps ~row target =
  List.find_opt (fun col -> steps.read_cell ~row ~col = Some target) [ 0; 1 ]

(* Over to [col] on the cursor's row: the cursor must read on it. *)
let across steps ~what ~target (c : Easy_chat_screen.cell) col =
  if col <> c.col then (
    steps.press (if col > c.col then Wire.Right else Wire.Left);
    let (on : Easy_chat_screen.cell) = steps.read_cursor () in
    if on.col <> col then
      M.fail "easy_chat_no_cursor"
        (Printf.sprintf "the cursor did not reach %s %s" what target))

(* DOWN a row at a time until the cursor's row shows the target, then over to
   its column. *)
let rec scan steps ~what ~target rows =
  if rows = 0 then
    M.fail "easy_chat_not_found" (Printf.sprintf "no %s %s" what target)
  else
    let (c : Easy_chat_screen.cell) = steps.read_cursor () in
    match column_of steps ~row:c.row target with
    | Some col -> across steps ~what ~target c col
    | None ->
        steps.press Wire.Down;
        scan steps ~what ~target (rows - 1)

let screen_game_steps ~what ~reader ~line ~width ~candidates =
  {
    read_cursor = (fun () -> cursor what reader);
    read_cell = (fun ~row ~col -> read_cell (line ~row ~col ~width) candidates);
    press = press move_ms;
  }

let group_of words (w : word) =
  match Words.group words w.group with
  | Some g when List.mem w.word g.words -> g
  | Some _ ->
      M.fail ~repeats:true "bad_args"
        (Printf.sprintf "%s is not in the group %s" w.word w.group)
  | None -> M.fail ~repeats:true "bad_args" ("no Easy Chat group " ^ w.group)

let choose ~log words (w : word) =
  let g = group_of words w in
  press open_ms Wire.A;
  scan
    (screen_game_steps ~what:"group" ~reader:Easy_chat_screen.group_cell
       ~line:Text.Text_lines.easy_chat_group_cell ~width:group_width
       ~candidates:(Words.names words))
    ~what:"group" ~target:w.group max_rows;
  log ("Easy Chat: group " ^ w.group ^ ".");
  press open_ms Wire.A;
  scan
    (screen_game_steps ~what:"word" ~reader:Easy_chat_screen.word_cell
       ~line:Text.Text_lines.easy_chat_word_cell ~width:word_width
       ~candidates:(Words.look_alikes g w.word))
    ~what:"word" ~target:w.word max_rows;
  press open_ms Wire.A;
  log ("Easy Chat: " ^ w.word ^ ".")

let left_of_field glyphs ~shown i =
  if field_col i = 0 then Text.Mail_fields.first_left
  else
    match
      Text.Mail_fields.next_left glyphs ~left:Text.Mail_fields.first_left
        (shown (i - 1))
    with
    | Ok left -> left
    | Error why -> M.fail ~repeats:true "bad_args" why

(* Field [i] must read [expect]; [shown j] is what field [j] shows. *)
let check_field ~code ~shown ~candidates i expect =
  let glyphs = Text_data.glyphs () in
  let left = left_of_field glyphs ~shown i in
  match
    Text.Mail_fields.read_field glyphs ~row:(field_row i) ~left
      (expect :: List.filter (fun c -> c <> expect) candidates)
  with
  | Ok (Read { text; _ }) when text = expect -> ()
  | Ok (Read { text; _ }) ->
      M.fail code
        (Printf.sprintf "field %d reads %s, not %s" (i + 1) text expect)
  | Ok (No_match _) ->
      M.fail code (Printf.sprintf "field %d does not read %s" (i + 1) expect)
  | Error why -> M.fail code why

let check_unchanged ~count =
  List.iter
    (fun i ->
      check_field ~code:"not_question_mark_mail"
        ~shown:(fun _ -> unknown)
        ~candidates:[ Text.Mail_fields.blank ] i unknown)
    (List.init count Fun.id)

let look_alikes words (w : word) = Words.look_alikes (group_of words w) w.word

let write ~log ws =
  let words = words () in
  let typed = Array.of_list (List.map (fun (w : word) -> w.word) ws) in
  let shown_upto n j = if j < n then typed.(j) else unknown in
  let check n i =
    check_field ~code:"mail_word_wrong" ~shown:(shown_upto n)
      ~candidates:(unknown :: look_alikes words (List.nth ws i))
      i typed.(i)
  in
  List.iteri
    (fun i w ->
      if i > 0 then List.iter (press move_ms) (moves_to_next_field (i - 1));
      choose ~log words w;
      check (i + 1) i)
    ws;
  List.iteri (fun i _ -> check (List.length ws) i) ws;
  log
    ("Easy Chat: the message reads "
    ^ String.concat " / " (Array.to_list typed)
    ^ ".")
