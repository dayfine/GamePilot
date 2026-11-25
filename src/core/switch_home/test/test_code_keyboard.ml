(* The code keyboard (Code_keyboard): the presses that type a code, as the
   lab script's type_code_cmds prints them (plza_claim_and_bank.sh, run on
   these codes: D-pad as R/L/U/D, A), and the reader on PLZA's name keyboard
   (the same system keyboard, light theme, cursor on "1": console B's
   Japanese capture and the fork's German one, images/keyboard), with their
   colors shifted as well (fixtures/code_keyboard.shifted.probes.jsonl). The
   dark HOME menu and the user select pass the script's dark-grey test and
   show a cyan cursor of their own, so they read as the keyboard: the steps
   look for it only right after Mystery Gift's code entry, where neither
   shows. Brightened by 1.1, the light keys clip to white and are not read. *)

open Switch_home
module K = Code_keyboard

let letter = function
  | Wire.Right -> "R"
  | Wire.Left -> "L"
  | Wire.Up -> "U"
  | Wire.Down -> "D"
  | Wire.A -> "A"
  | b -> Wire.string_of_button b

let typed ?(from = K.first_key) code () =
  match K.presses ~from code with
  | Ok buttons -> String.concat " " (List.map letter buttons)
  | Error e -> "error: " ^ e

let case name input expectation : Table_test.case = { name; input; expectation }
let fixtures = Wire.read_image_probes "code_keyboard.probes.jsonl"
let shifted = Wire.read_image_probes "code_keyboard.shifted.probes.jsonl"

let text probes =
  let m : Wire.frame = { seq = 1; t_ms = 0.; probes } in
  let cursor =
    Option.fold ~none:"no cursor"
      ~some:(fun (k : K.key) -> Printf.sprintf "cursor (%d, %d)" k.row k.col)
      (K.cursor m)
  in
  (if K.shown m then "keyboard, " else "no keyboard, ") ^ cursor

let read name () = text (List.assoc ("./" ^ name ^ ".png") fixtures)

let unshifted image =
  match String.split_on_char '/' image with
  | [ "."; _; file ] -> "./" ^ file
  | _ -> failwith ("no shift in " ^ image)

let is_keyboard image = String.ends_with ~suffix:"-cursor-on-1.png" image

let expected image =
  if String.starts_with ~prefix:"./bright110/" image then
    "no keyboard, cursor (0, 0)"
  else text (List.assoc (unshifted image) fixtures)

let shifted_cases =
  List.map
    (fun (image, probes) ->
      case ("shifted: " ^ image) (fun () -> text probes) (expected image))
    (List.filter (fun (image, _) -> is_keyboard image) shifted)

let () =
  Table_test.run "code_keyboard"
    ([
       case "CELEBRATE30TH from 1" (typed "CELEBRATE30TH")
         "R R D D D A U U A D R R R R R R A L L L L L L U A R R D D A L U U A \
          L L L D A R R R R U A L L A U A R R R R R R R A L L L L L D A R D A";
       case "lower case, a space and a hyphen are the same code"
         (typed "celebrate 30-th") (typed "CELEBRATE30TH" ());
       case "P, X, Q: round the disabled keys" (typed "PXQ")
         "R R R R R R R R R D A D D L L L L L L L L A U U L A";
       case "M, 8" (typed "M8") "R R R R R R D D D A U U U R A";
       case "A, X, P" (typed "AXP") "D D A R D A U U R R R R R R R R A";
       case "from the cursor where it was: 9 from 8"
         (typed ~from:{ row = 0; col = 7 } "9")
         "R A";
       case "Z is disabled" (typed "ZZ") "error: no enabled key types 'Z'";
       case "I is disabled" (typed "1I") "error: no enabled key types 'I'";
       case "PLZA's Japanese name keyboard"
         (read "ja-name-light-cursor-on-1")
         "keyboard, cursor (0, 0)";
       case "PLZA's German name keyboard"
         (read "de-name-light-cursor-on-1")
         "keyboard, cursor (0, 0)";
       case "HOME (dark), its tile cursor"
         (read "home-cursor-on-last-played")
         "keyboard, cursor (1, 3)";
       case "the user select" (read "user-select") "keyboard, cursor (2, 6)";
     ]
    @ shifted_cases)
