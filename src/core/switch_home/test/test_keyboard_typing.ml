(* The name typer (Keyboard_typing): the moves from key to key as the fork's
   keyboard_get_path makes them (rows first, then the short way round the
   twelve columns, wrapping at the sides), and names typed on a scripted
   keyboard: upper case with Shift (LStick) first, the cursor read before each
   key, a dropped move corrected on the next read, a cursor left on the right
   column (which does not read) failing after ten tries, a press the field
   does not take failing, and a character with no key refused before any
   press. *)

open Switch_home
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

let typed ?(row = 0) ?(col = 0) ?(drop = 0) ?(dead = false) name () =
  let k = { row; col; text = ""; shift = false; drop; presses = []; dead } in
  let outcome =
    match T.type_text (steps k) name with Ok () -> "ok" | Error e -> e
  in
  Printf.sprintf "%s; field \"%s\"; pressed %s" outcome k.text
    (String.concat " " (List.rev k.presses))

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "keyboard_typing"
    [
      case "1 to K: down, then left round the side" (path '1' 'K')
        "D D L* L L L L";
      case "Q to P: left round the side" (path 'Q' 'P') "L* L L";
      case "A to !: left round the side twice" (path 'A' '!') "D L* L";
      case "! to Z: right round the side" (path '!' 'Z') "R R*";
      case "the same key: no move" (path 'k' 'K') "";
      case "Kosmos from 1: Shift for K only" (typed "Kosmos")
        "ok; field \"Kosmos\"; pressed Down Down Left Left Left Left Left \
         LStick A Up Right A Down Right Right Right Right Right A Down Right \
         Right Right Right Right A Up Up Right Right A Down Right Right Right \
         Right Right A";
      case "Kosmos with two moves dropped: read and moved again"
        (typed ~drop:2 "Kosmos")
        "ok; field \"Kosmos\"; pressed Down Down Left Left Left Left Left Down \
         Down LStick A Up Right A Down Right Right Right Right Right A Down \
         Right Right Right Right Right A Up Up Right Right A Down Right Right \
         Right Right Right A";
      case "a1-/:',.?! from 1" (typed "a1-/:',.?!")
        "ok; field \"a1-/:',.?!\"; pressed Down Down A Up Up A Left Left A \
         Down A Down Left A Right A Down Left Left Left A Right A Right A \
         Right A";
      case "the cursor on the right column: no read, ten tries"
        (typed ~col:11 "q")
        "System keyboard: the cursor could not be read while moving to 'q' at \
         (1, 0), after 10 tries.; field \"\"; pressed ";
      case "a key the field does not take" (typed ~dead:true "q")
        "System keyboard: pressed 'q', but the text field did not change (0 -> \
         0 white pixels).; field \"\"; pressed Down A";
      case "an accented letter: refused, nothing pressed" (typed "Jos\xc3\xa9")
        "System keyboard: \"Jos\xc3\xa9\" has characters with no key on the \
         keyboard: \"\xc3\xa9\".; field \"\"; pressed ";
    ]
