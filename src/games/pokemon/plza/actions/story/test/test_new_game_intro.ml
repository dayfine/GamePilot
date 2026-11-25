(* 01.00a (New_game_intro) on a scripted console: HOME, the launch, the logos,
   the language list (the D-pad moves its highlight), the look picker (no
   highlight until the first tilt, which lands on a look of the console's
   choosing; each tilt moves it after), the name keyboard (the D-pad moves its
   cursor round twelve columns, A types, LStick shifts the next key), and +
   to Confirm Choices (a Chinese keyboard takes one + to accept the text
   first). Each case prints how the run ended and what the game was given.
   Also the choices refused before any press (New_game_choices.problem, the
   fork's run-problem cases of PokemonLZA_AutoStoryNewGame_Tests.cpp). *)

open Plza_story
module I = New_game_intro
module C = New_game_choices
module S = New_game_screen

type phase =
  | Home
  | Logos of float  (** until *)
  | Languages of int
  | Picker of int option
  | Keyboard of { since : float; pluses : int }
  | Confirm
  | Gone  (** a screen nothing reads *)

type console = {
  mutable now : float;
  mutable phase : phase;
  mutable dimmed : bool;
  mutable language : int option;
  mutable look : int option;
  mutable row : int;
  mutable col : int;
  mutable text : string;
  mutable shift : bool;
  mutable presses : int;
  first_look : int;
  accept_pluses : int;  (** + presses the keyboard takes before Confirm *)
  launches : bool;
  picker_lights : bool;
}

let logos_ms = 15_000.
let read_ms = 33.
let keyboard_slide_ms = 500.
let ring = 12
let rows = 4
let list_rows = 5
let look_columns = 4
let layout = [| "1234567890-"; "qwertyuiop/"; "asdfghjkl:'"; "zxcvbnm,.?!" |]

let step_grid (c, r) ~cols ~rows = function
  | Wire.Right -> (min (cols - 1) (c + 1), r)
  | Wire.Left -> (max 0 (c - 1), r)
  | Wire.Down -> (c, min (rows - 1) (r + 1))
  | Wire.Up -> (c, max 0 (r - 1))
  | _ -> (c, r)

let on_language k entry b =
  match b with
  | Wire.A ->
      k.language <- Some entry;
      k.phase <- Picker None
  | b ->
      let c, r =
        step_grid
          (entry / list_rows, entry mod list_rows)
          ~cols:2 ~rows:list_rows b
      in
      k.phase <- Languages ((c * list_rows) + r)

let on_keyboard k b =
  match b with
  | Wire.LStick -> k.shift <- true
  | Wire.A when k.col < ring - 1 ->
      let ch = layout.(k.row).[k.col] in
      k.text <-
        k.text ^ String.make 1 (if k.shift then Char.uppercase_ascii ch else ch);
      k.shift <- false
  | Wire.Right -> k.col <- (k.col + 1) mod ring
  | Wire.Left -> k.col <- (k.col + ring - 1) mod ring
  | Wire.Up -> k.row <- max 0 (k.row - 1)
  | Wire.Down -> k.row <- min (rows - 1) (k.row + 1)
  | _ -> ()

let plus k ~since ~pluses =
  if pluses + 1 >= k.accept_pluses then k.phase <- Confirm
  else k.phase <- Keyboard { since; pluses = pluses + 1 }

let on_button k b =
  k.presses <- k.presses + 1;
  match (k.phase, b) with
  | Home, Wire.B -> k.dimmed <- false
  | Languages entry, b -> on_language k entry b
  | Picker (Some l), Wire.A ->
      k.look <- Some l;
      k.phase <- Keyboard { since = k.now; pluses = 0 }
  | Keyboard { since; pluses }, Wire.Start -> plus k ~since ~pluses
  | Keyboard _, b -> on_keyboard k b
  | _ -> ()

let direction (x, y) =
  if x > 0.5 then Wire.Right
  else if x < -0.5 then Wire.Left
  else if y > 0.5 then Wire.Up
  else Wire.Down

let on_tilt k (s : Wire.stick) =
  k.presses <- k.presses + 1;
  match k.phase with
  | Picker None when k.picker_lights -> k.phase <- Picker (Some k.first_look)
  | Picker (Some l) ->
      let c, r =
        step_grid
          ((l - 1) mod look_columns, (l - 1) / look_columns)
          ~cols:look_columns ~rows:2
          (direction (s :> float * float))
      in
      k.phase <- Picker (Some ((r * look_columns) + c + 1))
  | _ -> ()

let submit k cmds =
  List.iter
    (function
      | Wire.Press { buttons; left_stick; hold_ms; cooldown_ms; _ } ->
          k.now <- k.now +. float_of_int (hold_ms + cooldown_ms);
          Option.iter (on_tilt k) left_stick;
          List.iter (on_button k) buttons
      | Wire.Wait { wait_ms } -> k.now <- k.now +. float_of_int wait_ms)
    cmds

let read k () : S.t =
  k.now <- k.now +. read_ms;
  (match k.phase with
  | Logos until when k.now >= until -> k.phase <- Languages 0
  | _ -> ());
  match k.phase with
  | Home -> { S.nothing with home = not k.dimmed }
  | Logos _ | Gone -> S.nothing
  | Languages e -> { S.nothing with language_entry = Some e }
  | Picker l -> { S.nothing with look_picker = true; look = l }
  | Keyboard { since; _ } when k.now -. since < keyboard_slide_ms -> S.nothing
  | Keyboard _ ->
      {
        S.nothing with
        name_keyboard = true;
        keyboard_cursor =
          (if k.col = ring - 1 then None
           else Some { Switch_home.Code_keyboard.row = k.row; col = k.col });
        text_pixels = 110 * String.length k.text;
      }
  | Confirm -> { S.nothing with confirm_choices = true }

let launch k () =
  if k.launches then (
    k.now <- k.now +. 5000.;
    k.phase <- Logos (k.now +. logos_ms);
    Ok ())
  else Error "PLZA's tile did not start"

let console ?(dimmed = false) ?(home = true) ?(first_look = 6)
    ?(accept_pluses = 1) ?(launches = true) ?(picker_lights = true) () =
  {
    now = 0.;
    phase = (if home then Home else Gone);
    dimmed;
    language = None;
    look = None;
    row = 0;
    col = 0;
    text = "";
    shift = false;
    presses = 0;
    first_look;
    accept_pluses;
    launches;
    picker_lights;
  }

let steps k : I.game_steps =
  {
    read_screen = read k;
    submit = submit k;
    launch = launch k;
    now = (fun () -> k.now);
    log = ignore;
  }

let opt = function Some n -> string_of_int n | None -> "none"

let played ?(choices = C.default) k () =
  let outcome =
    match I.run (steps k) choices with
    | Ok () -> "passed"
    | Error c -> Engine_run.Failure.cause_to_string c
  in
  Printf.sprintf "%s; language %s, look %s, name \"%s\", %d presses" outcome
    (opt k.language) (opt k.look) k.text k.presses

let refused choices () =
  match C.problem choices with Some p -> p | None -> "no problem"

let case name input expectation : Table_test.case = { name; input; expectation }
let hint = C.by_hand_hint
let with_name name = { C.default with name }

let runs =
  [
    case "the defaults: English, look 1, Kosmos"
      (played (console ()))
      "passed; language 0, look 1, name \"Kosmos\", 44 presses";
    case "a dimmed HOME: B wakes it"
      (played (console ~dimmed:true ()))
      "passed; language 0, look 1, name \"Kosmos\", 45 presses";
    case "Japanese, look 7, the first tilt on 7"
      (played
         ~choices:{ language = Japanese; look = 7; name = "1" }
         (console ~first_look:7 ()))
      "passed; language 6, look 7, name \"1\", 7 presses";
    case "Traditional Chinese: two + to Confirm Choices"
      (played
         ~choices:{ language = Chinese_traditional; look = 8; name = "q" }
         (console ~accept_pluses:2 ()))
      "passed; language 9, look 8, name \"q\", 14 presses";
    case "not on HOME: one B, refused"
      (played (console ~home:false ()))
      ("new_game_refused: AutoStory: 01.00a starts a new game (no save) from \
        the Switch HOME. It is not on screen; pressed B once to wake the \
        screen, nothing else was pressed. " ^ hint
     ^ "; language none, look none, name \"\", 1 presses");
    case "the launch fails"
      (played (console ~launches:false ()))
      ("new_game_failed: AutoStory intro: the launch from HOME failed: PLZA's \
        tile did not start " ^ hint
     ^ "; language none, look none, name \"\", 0 presses");
    case "the picker never lights: six tilts left, then fails"
      (played (console ~picker_lights:false ()))
      ("new_game_failed: AutoStory intro: the look picker's highlight was not \
        read on look 1. " ^ hint
     ^ "; language 0, look none, name \"\", 8 presses");
    case "look 9: refused before any press"
      (played ~choices:{ C.default with look = 9 } (console ()))
      ("new_game_refused: AutoStory: the player look must be 1 to 8, not 9. "
     ^ hint ^ "; language none, look none, name \"\", 0 presses");
  ]

let hangul_6 =
  "\xec\xbd\x94\xec\x8a\xa4\xeb\xaa\xa8\xec\x8a\xa4\xec\xbd\x94\xec\x8a\xa4"

let problems =
  [
    case "the defaults" (refused C.default) "no problem";
    case "13 characters in English"
      (refused (with_name "Abcdefghijklm"))
      "AutoStory: the player name \"Abcdefghijklm\" has 13 characters; the \
       game takes at most 12 in this language (en).";
    case "7 characters in Japanese"
      (refused { C.default with language = Japanese; name = "Kosmoss" })
      "AutoStory: the player name \"Kosmoss\" has 7 characters; the game takes \
       at most 6 in this language (ja).";
    case "an empty name"
      (refused (with_name ""))
      "AutoStory: the player name is empty.";
    case "look 9"
      (refused { C.default with look = 9 })
      "AutoStory: the player look must be 1 to 8, not 9.";
    case "Korean, six Hangul characters"
      (refused { C.default with language = Korean; name = hangul_6 })
      "AutoStory: the program cannot type a name on the ko keyboard (Hangul).";
    case "Simplified Chinese (ours: its keyboard opens in Pinyin)"
      (refused { C.default with language = Chinese_simplified; name = "q" })
      "AutoStory: the program cannot type a name on the zh-Hans keyboard \
       (Pinyin).";
    case "digits and the first page's symbols"
      (refused (with_name "a1-/:',.?!"))
      "no problem";
    case "an accented letter"
      (refused (with_name "Jos\xc3\xa9"))
      "AutoStory: the player name \"Jos\xc3\xa9\" has a character that is not \
       on the name keyboard's first page (letters, digits and - / : ' , . ? \
       !).";
    case "a symbol of the second page"
      (refused (with_name "a#"))
      "AutoStory: the player name \"a#\" has a character that is not on the \
       name keyboard's first page (letters, digits and - / : ' , . ? !).";
    case "every tag"
      (fun () -> String.concat " " C.tags)
      "en es-ES es-419 fr de it ja ko zh-Hans zh-Hant";
  ]

let () = Table_test.run "new_game_intro" (runs @ problems)
