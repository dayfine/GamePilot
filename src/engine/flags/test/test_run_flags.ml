(* gamepilot run's --options: one KEY=VALUE each, repeatable, collected in the
   order given; the keys are the program's to check (Run_options). *)

let no_game : unit Run_flags.game_flags =
  {
    game_defaults = ();
    game_switch = (fun () _ -> None);
    game_valued = (fun () _ _ -> Run_flags.Not_game_flag);
  }

let options args () =
  match Run_flags.parse no_game (Run_flags.defaults no_game) args with
  | Ok f -> String.concat " " (List.map (fun (k, v) -> k ^ "=" ^ v) f.options)
  | Error e -> "error: " ^ e

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "run_flags"
    [
      case "none" (options []) "";
      case "one"
        (options [ "--options"; "item=master-ball" ])
        "item=master-ball";
      case "repeated, in order, among other flags"
        (options
           [
             "--options";
             "item=master-ball";
             "--from";
             "01";
             "--options";
             "withdraw=50";
           ])
        "item=master-ball withdraw=50";
      case "a value with a comma and an ="
        (options [ "--options"; "name=a,b=c" ])
        "name=a,b=c";
      case "no ="
        (options [ "--options"; "item" ])
        "error: --options item: not KEY=VALUE";
    ]
