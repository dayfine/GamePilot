(* 01.00a-new-game's choices as plza.autostory's options: their declaration
   (Plza_story.New_game_choices.decls, through Run_options.check) reads each key's
   values, and
   New_game_options.of_run_options the choices 01.00a-new-game plays and the rules
   across keys, before anything is pressed. One fact per case: the choice's
   language, look or name, or the refusal. *)

module Options = Plza_autostory.New_game_options
module Choices = Plza_story.New_game_choices

let case name input expectation = { Table_test.name; input; expectation }

(* The choices 01.00a-new-game would play with [pairs], one --options each, over
   the fork's defaults; [part] picks the one fact a case checks. *)
let played part pairs () =
  match
    Result.bind (Run_options.check Choices.decls pairs) Options.of_run_options
  with
  | Ok o -> part (Options.over o Choices.default)
  | Error e -> "error: " ^ e

let language (c : Choices.t) = (Choices.info c.language).tag
let look (c : Choices.t) = string_of_int c.look
let name (c : Choices.t) = c.name

let cases =
  [
    case "no options: the language is en" (played language []) "en";
    case "no options: the look is 1" (played look []) "1";
    case "no options: the name is Kosmos" (played name []) "Kosmos";
    case "language=fr: the language"
      (played language [ ("language", "fr") ])
      "fr";
    case "language=zh-Hant: the language"
      (played language [ ("language", "zh-Hant") ])
      "zh-Hant";
    case "look=5: the look" (played look [ ("look", "5") ]) "5";
    case "look=5: the language stays en"
      (played language [ ("look", "5") ])
      "en";
    case "name=Ana: the name" (played name [ ("name", "Ana") ]) "Ana";
    case "a name keeps its commas" (played name [ ("name", "Ana,B") ]) "Ana,B";
    case "a name its language cannot take: refused"
      (played name [ ("name", "Kosmoss"); ("language", "ja") ])
      "error: AutoStory: the player name \"Kosmoss\" has 7 characters; the \
       game takes at most 6 in this language (ja).";
    case "language=ko: not one it types a name in"
      (played language [ ("language", "ko") ])
      "error: --options language=ko: language is en | es-ES | es-419 | fr | de \
       | it | ja | zh-Hant";
    case "look=9: out of range"
      (played look [ ("look", "9") ])
      "error: --options look=9: look is 1 to 8";
    case "name with a character not on the keyboard"
      (played name [ ("name", "K@smos") ])
      "error: AutoStory: the player name \"K@smos\" has a character that is \
       not on the name keyboard's first page (letters, digits and - / : ' , . \
       ? !).";
  ]

let () = Table_test.run "plza_new_game_options" cases
