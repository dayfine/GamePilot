(* Naming_entry on a fake naming screen that moves, types and turns pages as
   pokefirered src/naming_screen.c does ([HandleDpadMovement],
   [MainState_WaitPageSwap], [AddTextCharacter]), with faults on chosen A
   presses: a character typed twice, a wrong one, one dropped. And
   Naming_keyboard's grids. *)

open Frlg_actions
module N = Frlg_readers.Naming_screen
module K = Frlg_text.Naming_keyboard
module E = Naming_entry

type fault = Twice | Wrong of string | Dropped

type screen = {
  mutable page : N.page;
  mutable row : int;
  mutable col : int;  (** [N.columns page]: the button column *)
  mutable saved_row : int;
  mutable text : string list;
  mutable a_presses : int;
  mutable ok : bool;
  faults : (int * fault) list;  (** by A press, from 1 *)
  max_chars : int;
}

let key_row_to_button_row = [| 0; 1; 1; 2 |]
let button_row_to_key_row = [| 0; 0; 3 |]
let buttons = 3
let cols s = N.columns s.page
let on_buttons s = s.col = cols s
let add s c = if List.length s.text < s.max_chars then s.text <- s.text @ [ c ]

let delete s =
  s.text <- List.filteri (fun i _ -> i < List.length s.text - 1) s.text

let type_key s =
  s.a_presses <- s.a_presses + 1;
  let c = K.char_at s.page { row = s.row; col = s.col } in
  (match List.assoc_opt s.a_presses s.faults with
  | None -> add s c
  | Some Twice ->
      add s c;
      add s c
  | Some (Wrong w) -> add s w
  | Some Dropped -> ());
  if List.length s.text = s.max_chars then (
    s.col <- cols s;
    s.row <- 2)

let horizontal s dx =
  let prev = s.col in
  let x = s.col + dx in
  s.col <- (if x < 0 then cols s else if x > cols s then 0 else x);
  if on_buttons s then (
    s.saved_row <- s.row;
    s.row <- key_row_to_button_row.(s.row))
  else if prev = cols s then
    s.row <- (if s.row = 1 then s.saved_row else button_row_to_key_row.(s.row))

let vertical s dy =
  let n = if on_buttons s then buttons else N.rows in
  s.row <- (s.row + dy + n) mod n

let turn_page s =
  let last = on_buttons s in
  s.page <- K.next_page s.page;
  s.col <- (if last then cols s else min s.col (cols s - 1))

let press s (b : Wire.button) =
  match b with
  | Up -> vertical s (-1)
  | Down -> vertical s 1
  | Left -> horizontal s (-1)
  | Right -> horizontal s 1
  | Select -> turn_page s
  | B -> delete s
  | Start ->
      s.col <- cols s;
      s.row <- 2
  | A when not (on_buttons s) -> type_key s
  | A when s.row = 0 -> turn_page s
  | A when s.row = 1 -> delete s
  | A -> s.ok <- true
  | _ -> ()

let steps s : E.game_steps =
  {
    read_page = (fun () -> s.page);
    read_key =
      (fun page ->
        if page = s.page && not (on_buttons s) then
          Some { N.row = s.row; col = s.col }
        else None);
    read_cell =
      (fun i -> Some (Option.value (List.nth_opt s.text i) ~default:" "));
    press = press s;
  }

let fresh ?(faults = []) () =
  {
    page = Upper;
    row = 0;
    col = 0;
    saved_row = 0;
    text = [];
    a_presses = 0;
    ok = false;
    faults;
    max_chars = E.box_name_chars;
  }

(* The entry when OK was pressed, or the failure's code. *)
let typed ?faults text () =
  let s = fresh ?faults () in
  match E.type_text (steps s) ~log:ignore ~max_chars:E.box_name_chars text with
  | () ->
      Printf.sprintf "%s%s" (String.concat "" s.text)
        (if s.ok then " OK" else " no OK")
  | exception Menu_input.Action_failed c ->
      Printf.sprintf "%s after %d A presses" c.code s.a_presses

let moves from to_ () =
  E.moves from to_ |> List.map Wire.string_of_button |> String.concat " "

let key row col : N.key = { row; col }

let position page c () =
  match K.find ~on:page c with
  | None -> "none"
  | Some p ->
      Printf.sprintf "%s r%dc%d"
        (match p.page with
        | Upper -> "upper"
        | Lower -> "lower"
        | Others -> "others")
        p.key.row p.key.col

(* Every character the keyboard types, eight at a time. *)
let chunks () =
  let rec go acc = function
    | [] -> List.rev acc
    | l ->
        let n = min E.box_name_chars (List.length l) in
        go
          (String.concat "" (List.filteri (fun i _ -> i < n) l) :: acc)
          (List.filteri (fun i _ -> i >= n) l)
  in
  go [] (List.filter (fun c -> c <> " ") K.charset)

let all_typed () =
  chunks ()
  |> List.filter (fun t -> typed t () <> t ^ " OK")
  |> String.concat ", "

let case name input expectation : Table_test.case = { name; input; expectation }

let cases =
  [
    case "a box name of every page" (typed "Az!…'.,9") "Az!…'.,9 OK";
    case "spaces and short" (typed "A b") "A b OK";
    case "every character, eight at a time" all_typed "";
    case "a character typed twice is deleted"
      (typed ~faults:[ (2, Twice) ] "ABC")
      "ABC OK";
    case "a wrong character is deleted and typed again"
      (typed ~faults:[ (1, Wrong "Q") ] "ABC")
      "ABC OK";
    case "a dropped A is typed again"
      (typed ~faults:[ (3, Dropped) ] "ABC")
      "ABC OK";
    case "the last of eight typed wrong: off the OK button and back"
      (typed ~faults:[ (8, Wrong "Q") ] "ABCDEFGH")
      "ABCDEFGH OK";
    case "wrong every time: gives up before OK"
      (typed ~faults:[ (1, Wrong "Q"); (2, Wrong "Q"); (3, Wrong "Q") ] "ABC")
      "naming_text_wrong after 3 A presses";
    case "an accented letter: refused before any press" (typed "é")
      "bad_args after 0 A presses";
    case "nine characters: refused" (typed "ABCDEFGHI")
      "bad_args after 0 A presses";
    case "spaces only: refused" (typed "   ") "bad_args after 0 A presses";
    case "moves: up across the wrap"
      (moves (key 0 0) (key 3 7))
      "Up Right Right Right Right Right Right Right";
    case "moves: two down on a tie"
      (moves (key 1 5) (key 3 2))
      "Down Down Left Left Left";
    case "keyboard: 76 characters"
      (fun () -> string_of_int (List.length K.charset))
      "76";
    case "keyboard: a full stop on the small letters" (position Lower ".")
      "lower r0c7";
    case "keyboard: a full stop from the others page" (position Others ".")
      "upper r0c7";
    case "keyboard: a space on the others page" (position Others " ")
      "others r0c5";
    case "keyboard: the female sign" (position Upper "♀") "others r2c3";
    case "keyboard: no é" (position Upper "é") "none";
  ]

let () = Table_test.run "naming_entry" cases
