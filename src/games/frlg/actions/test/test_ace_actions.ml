(* The ACE setup's decisions on fakes: Easy_chat_entry's scan through a word
   list made up here (four rows shown, two words a row, the list scrolling
   under the cursor as the game's does), and Ace_mail's verdict on a box screen
   given as readings. *)

open Frlg_actions

let case name input expectation = { Table_test.name; input; expectation }
let rows_shown = 4

(* The fake list: the cursor's row in the whole list, its column, the first
   row shown, and every press taken. [stuck] makes LEFT and RIGHT do
   nothing. *)
type list_game = {
  words : string array;
  mutable row : int;
  mutable col : int;
  mutable top : int;
  mutable presses : string list;
  stuck : bool;
}

let list_game ?(stuck = false) words =
  {
    words = Array.of_list words;
    row = 0;
    col = 0;
    top = 0;
    presses = [];
    stuck;
  }

let word_at g ~row ~col =
  let i = (row * 2) + col in
  if i < Array.length g.words then Some g.words.(i) else None

let press g (b : Wire.button) =
  g.presses <- Wire.string_of_button b :: g.presses;
  match b with
  | Down when word_at g ~row:(g.row + 1) ~col:0 <> None ->
      g.row <- g.row + 1;
      if g.row - g.top >= rows_shown then g.top <- g.top + 1;
      if word_at g ~row:g.row ~col:g.col = None then g.col <- 0
  | Right when (not g.stuck) && word_at g ~row:g.row ~col:1 <> None ->
      g.col <- 1
  | Left when not g.stuck -> g.col <- 0
  | _ -> ()

let fake_game_steps g : Easy_chat_entry.game_steps =
  {
    read_cursor = (fun () -> { row = g.row - g.top; col = g.col });
    read_cell = (fun ~row ~col -> word_at g ~row:(g.top + row) ~col);
    press = press g;
  }

let moves = [ "CUT"; "DIG"; "FLY"; "BIND"; "BIDE"; "SURF"; "BITE"; "TACKLE" ]
let moves = moves @ [ "GROWL"; "SING"; "KARATE CHOP"; "ROAR" ]

(* Where the cursor ends (the word under it) and the presses, or the failure. *)
let scan ?stuck ?(rows = 130) target () =
  let g = list_game ?stuck moves in
  match Easy_chat_entry.scan (fake_game_steps g) ~what:"word" ~target rows with
  | () ->
      Printf.sprintf "on %s after [%s]"
        (Option.value ~default:"-" (word_at g ~row:g.row ~col:g.col))
        (String.concat " " (List.rev g.presses))
  | exception Menu_input.Action_failed c ->
      Pokemon_checkpoints.Failure.cause_to_string c

let scan_cases =
  [
    case "scan: the first word: no press" (scan "CUT") "on CUT after []";
    case "scan: the first row's second word: RIGHT" (scan "DIG")
      "on DIG after [Right]";
    case "scan: a word below: DOWN until its row shows, then across"
      (scan "BIND") "on BIND after [Down Right]";
    case "scan: past the rows shown, the list scrolls" (scan "KARATE CHOP")
      "on KARATE CHOP after [Down Down Down Down Down]";
    case "scan: a word the list lacks: not found once the rows run out"
      (scan ~rows:8 "THRASH")
      (Pokemon_checkpoints.Failure.cause_to_string
         (Pokemon_checkpoints.Failure.cause "easy_chat_not_found"
            "no word THRASH"));
    case "scan: the cursor does not move across: no cursor on it"
      (scan ~stuck:true "DIG")
      (Pokemon_checkpoints.Failure.cause_to_string
         (Pokemon_checkpoints.Failure.cause "easy_chat_no_cursor"
            "the cursor did not reach word DIG"));
  ]

(* {1 The box slot's verdict} *)

let empty_slot : Ace_mail.slot_check =
  { box = 3; slot = 1; occupied = false; level = None; male = None }

let ace_slot : Ace_mail.slot_check =
  { box = 3; slot = 1; occupied = true; level = Some 100; male = Some true }

let view ?(panel = Some false) ?(desert = Some true) ?(hand = Some true)
    ?(male = None) ?(level = 0) () : Ace_mail.box_view =
  {
    panel_occupied = panel;
    desert;
    hand_on_first_slot = hand;
    male;
    level_shown = (fun l -> l = level);
  }

let ace_view ?male ?level () =
  view ~panel:(Some true) ~hand:(Some false)
    ~male:(Option.value male ~default:(Some true))
    ~level:(Option.value level ~default:100)
    ()

let verdict c v () =
  match Ace_mail.slot_verdict c v with
  | As_asked -> "as asked"
  | Wrong why -> "wrong: " ^ why
  | Unread why -> "unread: " ^ why

let verdict_cases =
  [
    case "verdict: Box 3's empty first slot under the hand"
      (verdict empty_slot (view ()))
      "as asked";
    case "verdict: empty, but the hand's shadow is not on slot 1"
      (verdict empty_slot (view ~hand:(Some false) ()))
      "wrong: the hand is not on the first slot";
    case "verdict: empty asked, the slot occupied"
      (verdict empty_slot (ace_view ()))
      "wrong: slot 1 is occupied";
    case "verdict: not Box 3's wallpaper"
      (verdict empty_slot (view ~desert:(Some false) ()))
      "wrong: BOX 3's Desert wallpaper is not shown";
    case "verdict: the ACE Pokemon, male, Lv 100"
      (verdict ace_slot (ace_view ()))
      "as asked";
    case "verdict: occupied, female"
      (verdict ace_slot (ace_view ~male:(Some false) ()))
      "wrong: the gender mark is not as asked";
    case "verdict: occupied, another level"
      (verdict ace_slot (ace_view ~level:5 ()))
      "wrong: the level is not as asked";
    case "verdict: occupied asked, the slot empty"
      (verdict ace_slot (view ()))
      "wrong: slot 1 is empty";
    case "verdict: PKMN DATA unread"
      (verdict ace_slot (view ~panel:None ()))
      "unread: PKMN DATA did not read";
    case "verdict: the wallpaper unread"
      (verdict ace_slot (view ~desert:None ()))
      "unread: the wallpaper did not read";
  ]

let () = Table_test.run "ace actions" (scan_cases @ verdict_cases)
