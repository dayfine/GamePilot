(* gamepilot run's --options KEY=VALUE[,KEY=VALUE...] (Run_flags):
   the syntax the engine parses for every program, in order, with syntax
   errors only; the keys and values are the program's. *)

let case name input expectation = { Table_test.name; input; expectation }

let no_game : unit Run_flags.game_flags =
  {
    game_defaults = ();
    game_switch = (fun () _ -> None);
    game_valued = (fun () _ _ -> None);
  }

let show options =
  String.concat "; " (List.map (fun (k, v) -> k ^ "=[" ^ v ^ "]") options)

(* The options parsed from [args], as text. *)
let parsed args () =
  match Run_flags.parse no_game (Run_flags.defaults no_game) args with
  | Ok f -> "ok: " ^ show f.options
  | Error e -> "error: " ^ e

(* A program's keys: look (a number) and name, read into "look/name". *)
let look_and_name : (string * string) Run_flags.option_keys =
  {
    unset = ("-", "-");
    keys =
      [
        ( "look",
          fun (_, name) v ->
            match int_of_string_opt v with
            | Some n -> Ok (string_of_int n, name)
            | None -> Error ("look is a number, not " ^ v) );
        ("name", fun (look, _) v -> Ok (look, v));
      ];
  }

let read keys options () =
  match Run_flags.read_options keys options with
  | Ok (look, name) -> "ok: " ^ look ^ "/" ^ name
  | Error e -> "error: " ^ e

let no_keys options () =
  match Run_flags.read_options Run_flags.no_option_keys options with
  | Ok () -> "ok"
  | Error e -> "error: " ^ e

let read_cases =
  [
    case "a program's keys: none given" (read look_and_name []) "ok: -/-";
    case "a program's keys, each read"
      (read look_and_name [ ("name", "Ana"); ("look", "5") ])
      "ok: 5/Ana";
    case "a key the program does not take: the keys it takes"
      (read look_and_name [ ("look", "5"); ("language", "fr") ])
      "error: --options: this program takes look and name, not language";
    case "a bad value: the program's refusal"
      (read look_and_name [ ("look", "five") ])
      "error: --options look is a number, not five";
    case "a program with no keys: no options" (no_keys []) "ok";
    case "a program with no keys refuses any"
      (no_keys [ ("look", "5") ])
      "error: --options: this program takes no options";
  ]

let cases =
  read_cases
  @ [
      case "no --options: none" (parsed [ "--from"; "a" ]) "ok: ";
      case "three pairs, in the order given"
        (parsed [ "--options"; "language=fr,look=5,name=Kosmos" ])
        "ok: language=[fr]; look=[5]; name=[Kosmos]";
      case "one pair among other flags"
        (parsed [ "--from"; "a"; "--options"; "look=5"; "--watch" ])
        "ok: look=[5]";
      case "a value keeps every = after the first"
        (parsed [ "--options"; "name=a=b" ])
        "ok: name=[a=b]";
      case "an empty value is the program's to refuse"
        (parsed [ "--options"; "name=" ])
        "ok: name=[]";
      case "an empty key"
        (parsed [ "--options"; "=fr" ])
        "error: --options: an empty key in =fr";
      case "an empty pair between commas"
        (parsed [ "--options"; "look=5,,name=Ana" ])
        "error: --options: an empty key in look=5,,name=Ana";
      case "a missing ="
        (parsed [ "--options"; "language" ])
        "error: --options: language has no =VALUE";
      case "a duplicate key"
        (parsed [ "--options"; "look=1,look=2" ])
        "error: --options: look is given twice";
      case "--options given twice"
        (parsed [ "--options"; "look=1"; "--options"; "name=Ana" ])
        "error: --options is given twice; give its pairs once, joined by commas";
      case "--options with no value" (parsed [ "--options" ])
        "error: unknown argument --options";
    ]

let () = Table_test.run "run_flags" cases
