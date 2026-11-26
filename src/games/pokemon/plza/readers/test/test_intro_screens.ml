(* The new game's readers (Switch_home_tile, Intro_screens, the keyboard's cursor and text
   field as Switch_home.Keyboard_typing reads them, Confirm_choices) on the
   fork's frames of 2026-11-15 (PokemonLZA_AutoStoryIntroScreens_Tests.cpp,
   AutoStoryNewGame/2026-11-15, images/new-game): the language list on each
   of its ten entries, the look picker before the stick moves and after the
   first tilt, the name keyboard in nine languages with the cursor on "1",
   Simplified Chinese's keyboard keeping "1" after the first +, and console
   B's Simplified Chinese keyboard of 2026-11-26 (dark, in English), and Confirm
   Choices after the name "1" (none of the others); and console B's Switch
   HOME (the home- frames, redacted to PLZA's title band, another game's title
   made a checkerboard: images/new-game/README.md): the cursor on PLZA's tile, first or scrolled to, reads as
   PLZA's tile, and on another tile with PLZA's in view (Pokémon HOME first
   and PLZA fourth, as the first 00.00-new-game run found it on 2026-11-25) does not. A frame reads as
   everything it shows, in one line. Every frame also reads the same with
   its colours shifted as another capture card might show them
   (fixtures/intro/intro.shifted.probes.jsonl, one shift per frame). *)

open Plza_readers
module T = Switch_home.Keyboard_typing

let frames = Wire.read_image_probes "fixtures/intro/intro.probes.jsonl"
let shifted = Wire.read_image_probes "fixtures/intro/intro.shifted.probes.jsonl"

(* A typed "1" adds about 110 white pixels; an empty field has none. *)
let has_text = 20

(* The keyboard's cursor and its text, read on the keyboard only. *)
let keyboard_parts m =
  [
    Some "keyboard";
    Option.map
      (fun (k : Switch_home.Code_keyboard.key) ->
        Printf.sprintf "cursor (%d, %d)" k.row k.col)
      (Switch_home.Code_keyboard.cursor m);
    (if T.text_pixels m >= has_text then Some "text" else None);
  ]

let parts (m : Effects.measurements) =
  [
    (if Switch_home_tile.on_plza_tile m then Some "PLZA's tile" else None);
    Option.map (Printf.sprintf "language %d") (Intro_screens.language_entry m);
    (if Intro_screens.look_picker_shown m then Some "look picker" else None);
    Option.map (Printf.sprintf "look %d") (Intro_screens.highlighted_look m);
  ]
  @ (if Intro_screens.name_keyboard_shown m then keyboard_parts m else [])
  @ [ Option.map (Printf.sprintf "confirm row %d") (Confirm_choices.read m) ]

let text probes =
  let m : Wire.frame = { seq = 1; t_ms = 0.; probes } in
  match List.filter_map Fun.id (parts m) with
  | [] -> "nothing"
  | p -> String.concat ", " p

(* The fork's frames are jpg, console B's redacted ones png. *)
let frame name =
  List.find_map
    (fun ext -> List.assoc_opt ("./new-game/" ^ name ^ ext) frames)
    [ ".jpg"; ".png" ]

let read name () =
  match frame name with
  | None -> "no frame " ^ name
  | Some probes -> text probes

(* "./<shift>/new-game/<frame>.png" to "<frame>". *)
let frame_of path = Filename.remove_extension (Filename.basename path)

(* The fork's light key row needs brightness 185: Traditional Chinese's
   keyboard is 206, 184 at 0.9 times as bright (the other keyboards 209). *)
let known_misses =
  [ "./bright90/new-game/name-keyboard-zhHant-cursor-on-1.png" ]

let shifted_cases =
  List.filter_map
    (fun (path, probes) : Table_test.case option ->
      if List.mem path known_misses then None
      else
        Some
          {
            name = path ^ ": reads as unshifted";
            input = (fun () -> text probes);
            expectation = read (frame_of path) ();
          })
    shifted

let case name expectation : Table_test.case =
  { name; input = read name; expectation }

let home =
  [
    case "home-cursor-on-za-first-tile" "PLZA's tile";
    case "home-scrolled-cursor-on-za" "PLZA's tile";
    case "home-cursor-on-pokemon-home-za-fourth" "nothing";
    case "home-cursor-on-brilliant-diamond-za-fourth" "nothing";
    case "home-scrolled-cursor-on-lets-go-pikachu" "nothing";
  ]

let languages =
  [
    case "language-list-en-opens-on-english" "language 0";
    case "language-list-on-1-espanol-espana" "language 1";
    case "language-list-on-2-espanol-latinoamerica" "language 2";
    case "language-list-on-3-francais" "language 3";
    case "language-list-on-4-deutsch" "language 4";
    case "language-list-on-5-italiano" "language 5";
    case "language-list-on-6-japanese" "language 6";
    case "language-list-on-7-korean" "language 7";
    case "language-list-on-8-chinese-simplified" "language 8";
    case "language-list-on-9-chinese-traditional" "language 9";
  ]

let looks =
  [
    case "look-picker-en-none-highlighted" "look picker";
    case "look-picker-en-on-6" "look picker, look 6";
    case "look-picker-ja-on-7" "look picker, look 7";
  ]

let keyboards =
  List.map
    (fun l ->
      case ("name-keyboard-" ^ l ^ "-cursor-on-1") "keyboard, cursor (0, 0)")
    [ "en"; "esES"; "esLA"; "fr"; "de"; "it"; "ja"; "zhHans"; "zhHant" ]
  @ [
      case "name-keyboard-zhHans-typed-1-after-plus"
        "keyboard, cursor (0, 0), text";
      (* Console B, 2026-11-26: the dark theme, opened in English (英文),
         the Latin page every other language types on. *)
      case "name-keyboard-zhHans-english-dark-cursor-on-1"
        "keyboard, cursor (0, 0)";
    ]

let confirms =
  [
    case "confirm-choices-en-name-1" "confirm row 0";
    case "confirm-choices-de-after-one-plus" "confirm row 0";
    case "confirm-choices-zhHant-after-two-plus" "confirm row 0";
  ]

let () =
  Table_test.run "intro_screens"
    (home @ languages @ looks @ keyboards @ confirms @ shifted_cases)
