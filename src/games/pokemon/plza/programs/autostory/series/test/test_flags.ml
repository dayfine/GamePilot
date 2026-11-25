(* PLZA's series flags (Plza_series.Flags.parse): 01.00a's new-game choices as
   program options (--language, --look, --name), and their bad values refused
   by parse, before anything is pressed. *)

module Options = Plza_autostory.New_game_options

let case name input expectation = { Table_test.name; input; expectation }
let from = [ "--from"; "01.00a"; "--to"; "03.11" ]

(* The choices 01.00a would play with [args] over the fork's defaults. *)
let parsed args () =
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
    case "--language fr"
      (parsed [ "--language"; "fr" ])
      {|fr, look 1, "Kosmos" (given: true)|};
    case "--language zh-Hant"
      (parsed [ "--language"; "zh-Hant" ])
      {|zh-Hant, look 1, "Kosmos" (given: true)|};
    case "--look 5"
      (parsed [ "--look"; "5" ])
      {|en, look 5, "Kosmos" (given: true)|};
    case "--name Ana"
      (parsed [ "--name"; "Ana" ])
      {|en, look 1, "Ana" (given: true)|};
    case "--language fr --look 5 --name Ana"
      (parsed [ "--language"; "fr"; "--look"; "5"; "--name"; "Ana" ])
      {|fr, look 5, "Ana" (given: true)|};
    case "--language xx: not a tag"
      (parsed [ "--language"; "xx" ])
      "error: --language is one of en, es-ES, es-419, fr, de, it, ja, zh-Hant, \
       not xx";
    case "--language ko: a keyboard 01.00a does not type on"
      (parsed [ "--language"; "ko" ])
      "error: AutoStory: the program cannot type a name on the ko keyboard \
       (Hangul).";
    case "--look 9: out of range"
      (parsed [ "--look"; "9" ])
      "error: --look is 1 to 8, not 9";
    case "--look 0: out of range"
      (parsed [ "--look"; "0" ])
      "error: --look is 1 to 8, not 0";
    case "--look five: not a number"
      (parsed [ "--look"; "five" ])
      "error: --look is 1 to 8, not five";
    case "--name empty"
      (parsed [ "--name"; "" ])
      "error: AutoStory: the player name is empty.";
    case "--name too long for Japanese"
      (parsed [ "--language"; "ja"; "--name"; "Kosmoss" ])
      "error: AutoStory: the player name \"Kosmoss\" has 7 characters; the \
       game takes at most 6 in this language (ja).";
    case "--name with a character not on the keyboard"
      (parsed [ "--name"; "K@smos" ])
      "error: AutoStory: the player name \"K@smos\" has a character that is \
       not on the name keyboard's first page (letters, digits and - / : ' , . \
       ? !).";
    case "--look with no value" (parsed [ "--look" ])
      "error: unknown argument --look";
  ]

let () = Table_test.run "plza_series_flags" cases
