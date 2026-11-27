(* The name typer (Keyboard_typing): the moves from key to key as the fork's
   keyboard_get_path makes them (rows first, then the short way round the
   twelve columns, wrapping at the sides), and names typed on a scripted
   keyboard: upper case with Shift (LStick) first, the cursor read before each
   key, a dropped move corrected on the next read, a cursor left on the right
   column (which does not read) failing after ten tries, a press the field
   does not take failing, and a character with no key refused before any
   press. *)

open Switch
module T = Keyboard_typing

let letter (m : T.move) =
  (match m.button with
  | Wire.Up -> "U"
  | Wire.Down -> "D"
  | Wire.Left -> "L"
  | Wire.Right -> "R"
  | b -> Wire.string_of_button b)
  ^ if m.wraps then "*" else ""

let path from target () =
  match (T.key_of_char from, T.key_of_char target) with
  | Some f, Some t -> String.concat " " (List.map letter (T.path ~from:f t))
  | _ -> "no key"

(* A keyboard: the cursor on a ring of twelve columns over four rows, the
   text typed so far, Shift for the next key. The right column (11) shows no
   cursor to the reader. [drop] moves are lost as the keyboard slides in;
   [dead] keys add nothing to the field. *)
type keyboard = {
  mutable row : int;
  mutable col : int;
  mutable text : string;
  mutable shift : bool;
  mutable drop : int;
  mutable presses : string list;  (** newest first *)
  dead : bool;
}

let layout = [| "1234567890-"; "qwertyuiop/"; "asdfghjkl:'"; "zxcvbnm,.?!" |]
let ring = 12
let rows = 4
let pixels_per_character = 110

let move k = function
  | Wire.Right -> k.col <- (k.col + 1) mod ring
  | Wire.Left -> k.col <- (k.col + ring - 1) mod ring
  | Wire.Up -> k.row <- max 0 (k.row - 1)
  | Wire.Down -> k.row <- min (rows - 1) (k.row + 1)
  | _ -> ()

let key_press k = function
  | Wire.LStick -> k.shift <- true
  | Wire.A when k.col < ring - 1 && not k.dead ->
      let ch = layout.(k.row).[k.col] in
      k.text <-
        k.text ^ String.make 1 (if k.shift then Char.uppercase_ascii ch else ch);
      k.shift <- false
  | Wire.A -> ()
  | _ when k.drop > 0 -> k.drop <- k.drop - 1
  | b -> move k b

let submit k cmds =
  List.iter
    (function
      | Wire.Press { buttons; _ } ->
          List.iter
            (fun b ->
              k.presses <- Wire.string_of_button b :: k.presses;
              key_press k b)
            buttons
      | Wire.Wait _ -> ())
    cmds

let steps k : T.game_steps =
  {
    read_cursor =
      (fun () ->
        if k.col = ring - 1 then None
        else Some { Code_keyboard.row = k.row; col = k.col });
    read_text_pixels = (fun () -> pixels_per_character * String.length k.text);
    submit = submit k;
    log = ignore;
  }

(* What a typing ends with: its outcome, the field, the presses. *)
type typing = { outcome : string; field : string; pressed : string }

let typed part ?(row = 0) ?(col = 0) ?(drop = 0) ?(dead = false) name () =
  let k = { row; col; text = ""; shift = false; drop; presses = []; dead } in
  let outcome =
    match T.type_text (steps k) name with Ok () -> "ok" | Error e -> e
  in
  part
    {
      outcome;
      field = k.text;
      pressed = String.concat " " (List.rev k.presses);
    }

(* The presses split at each A: one list per character typed. *)
let per_key t =
  let rec go current acc = function
    | [] -> List.rev acc
    | "A" :: rest -> go [] (List.rev current :: acc) rest
    | p :: rest -> go (p :: current) acc rest
  in
  go [] [] (String.split_on_char ' ' t.pressed)

(* The moves before the [n]th character's A (1 the first), Shift aside. *)
let moves_to n t =
  match List.nth_opt (per_key t) (n - 1) with
  | None -> "no such key"
  | Some ps -> String.concat " " (List.filter (fun p -> p <> "LStick") ps)

(* The characters typed with Shift first, by number. *)
let shifted t =
  per_key t
  |> List.mapi (fun i ps -> if List.mem "LStick" ps then Some (i + 1) else None)
  |> List.filter_map Fun.id |> List.map string_of_int |> String.concat " "

let a_presses t = string_of_int (List.length (per_key t))
let outcome t = t.outcome
let field t = t.field
let pressed t = t.pressed
let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "keyboard_typing"
    [
      case "1 to K: down, then left round the side" (path '1' 'K')
        "D D L* L L L L";
      case "Q to P: left round the side" (path 'Q' 'P') "L* L L";
      case "A to !: left round the side once" (path 'A' '!') "D L* L";
      case "! to Z: right round the side" (path '!' 'Z') "R R*";
      case "the same key: no move" (path 'k' 'K') "";
      case "Kosmos from 1: typed" (typed field "Kosmos") "Kosmos";
      case "Kosmos from 1: Shift for K only" (typed shifted "Kosmos") "1";
      case "Kosmos from 1: one A per character" (typed a_presses "Kosmos") "6";
      case "Kosmos from 1: to K, down then left round the side"
        (typed (moves_to 1) "Kosmos")
        "Down Down Left Left Left Left Left";
      case "Kosmos: K to o, up and right"
        (typed (moves_to 2) "Kosmos")
        "Up Right";
      case "Kosmos: o to s, down then right round the side"
        (typed (moves_to 3) "Kosmos")
        "Down Right Right Right Right Right";
      case "Kosmos: s to m, down then right"
        (typed (moves_to 4) "Kosmos")
        "Down Right Right Right Right Right";
      case "Kosmos: m to o, up twice and right"
        (typed (moves_to 5) "Kosmos")
        "Up Up Right Right";
      case "Kosmos: o to s again"
        (typed (moves_to 6) "Kosmos")
        "Down Right Right Right Right Right";
      case "Kosmos with two moves dropped: typed"
        (typed field ~drop:2 "Kosmos")
        "Kosmos";
      case "Kosmos with two moves dropped: K's two Downs sent again"
        (typed (moves_to 1) ~drop:2 "Kosmos")
        "Down Down Left Left Left Left Left Down Down";
      case "Kosmos with two moves dropped: o's moves as before"
        (typed (moves_to 2) ~drop:2 "Kosmos")
        "Up Right";
      case "a1-/:',.?! from 1: typed" (typed field "a1-/:',.?!") "a1-/:',.?!";
      case "a1-/:',.?! from 1: no Shift" (typed shifted "a1-/:',.?!") "";
      case "a1-/:',.?!: to a, down twice"
        (typed (moves_to 1) "a1-/:',.?!")
        "Down Down";
      case "a1-/:',.?!: a to 1, up twice"
        (typed (moves_to 2) "a1-/:',.?!")
        "Up Up";
      case "a1-/:',.?!: 1 to -, left round the side"
        (typed (moves_to 3) "a1-/:',.?!")
        "Left Left";
      case "a1-/:',.?!: - to /, down" (typed (moves_to 4) "a1-/:',.?!") "Down";
      case "a1-/:',.?!: ' to ',', down and three left"
        (typed (moves_to 7) "a1-/:',.?!")
        "Down Left Left Left";
      case "a1-/:',.?!: ? to !, right"
        (typed (moves_to 10) "a1-/:',.?!")
        "Right";
      case "the cursor on the right column: no read, ten tries"
        (typed outcome ~col:11 "q")
        "System keyboard: the cursor could not be read while moving to 'q' at \
         (1, 0), after 10 tries.";
      case "the cursor on the right column: nothing pressed"
        (typed pressed ~col:11 "q")
        "";
      case "a key the field does not take"
        (typed outcome ~dead:true "q")
        "System keyboard: pressed 'q', but the text field did not change (0 -> \
         0 white pixels).";
      case "a key the field does not take: the field stays empty"
        (typed field ~dead:true "q")
        "";
      case "an accented letter: refused"
        (typed outcome "Jos\xc3\xa9")
        "System keyboard: \"Jos\xc3\xa9\" has characters with no key on the \
         keyboard: \"\xc3\xa9\".";
      case "an accented letter: nothing pressed"
        (typed pressed "Jos\xc3\xa9")
        "";
    ]
