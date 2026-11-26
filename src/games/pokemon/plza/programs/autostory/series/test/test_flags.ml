(* PLZA's series flags (Plza_series.Flags.parse): 00-new-game's new-game choices as
   the program's options (--options KEY=VALUE, repeatable), and their bad
   values, unknown keys and repeated keys refused by parse, before anything is
   pressed. *)

module Options = Plza_autostory.New_game_options

let case name input expectation = { Table_test.name; input; expectation }
let from = [ "--from"; "00-new-game"; "--to"; "03.11" ]

(* The choices 00-new-game would play with [pairs], each its own --options, over
   the fork's defaults. *)
let parsed pairs () =
  let args = List.concat_map (fun p -> [ "--options"; p ]) pairs in
  match Plza_series.Flags.parse (from @ args) with
  | Ok f ->
      Printf.sprintf "%s (given: %b)"
        (Options.describe
           (Options.over f.game Plza_story.New_game_choices.default))
        (Options.given f.game)
  | Error e -> "error: " ^ e

let cases =
  [
    case "no options: the plan's choices" (parsed [])
      {|en, look 1, "Kosmos" (given: false)|};
    case "language=fr" (parsed [ "language=fr" ])
      {|fr, look 1, "Kosmos" (given: true)|};
    case "language=zh-Hant"
      (parsed [ "language=zh-Hant" ])
      {|zh-Hant, look 1, "Kosmos" (given: true)|};
    case "look=5" (parsed [ "look=5" ]) {|en, look 5, "Kosmos" (given: true)|};
    case "name=Ana" (parsed [ "name=Ana" ]) {|en, look 1, "Ana" (given: true)|};
    case "three --options, one pair each"
      (parsed [ "language=fr"; "look=5"; "name=Ana" ])
      {|fr, look 5, "Ana" (given: true)|};
    case "the name checked against the language given after it"
      (parsed [ "name=Kosmoss"; "language=ja" ])
      "error: AutoStory: the player name \"Kosmoss\" has 7 characters; the \
       game takes at most 6 in this language (ja).";
    case "language=xx: not a tag" (parsed [ "language=xx" ])
      "error: --options language is one of en, es-ES, es-419, fr, de, it, ja, \
       zh-Hant, not xx";
    case "language=ko: a keyboard 00-new-game does not type on"
      (parsed [ "language=ko" ])
      "error: AutoStory: the program cannot type a name on the ko keyboard \
       (Hangul).";
    case "look=9: out of range" (parsed [ "look=9" ])
      "error: --options look is 1 to 8, not 9";
    case "look=0: out of range" (parsed [ "look=0" ])
      "error: --options look is 1 to 8, not 0";
    case "look=five: not a number" (parsed [ "look=five" ])
      "error: --options look is 1 to 8, not five";
    case "name empty" (parsed [ "name=" ])
      "error: AutoStory: the player name is empty.";
    case "name with a character not on the keyboard" (parsed [ "name=K@smos" ])
      "error: AutoStory: the player name \"K@smos\" has a character that is \
       not on the name keyboard's first page (letters, digits and - / : ' , . \
       ? !).";
    case "a key autostory does not take: the keys it takes"
      (parsed [ "look=5"; "speed=2" ])
      "error: --options: autostory takes language, look, name, not speed";
    case "a pair with no =VALUE" (parsed [ "look" ])
      "error: --options: look has no =VALUE";
    case "an empty key" (parsed [ "=5" ]) "error: --options: an empty key in =5";
    case "a key given twice, in two --options"
      (parsed [ "look=5"; "look=6" ])
      "error: --options: look is given twice";
    case "a value keeps its commas" (parsed [ "name=Ana,B" ])
      {|en, look 1, "Ana,B" (given: true)|};
  ]

let () = Table_test.run "plza_series_flags" cases
