(* gamepilot setup / gamepilot doctor (docs/design/Release-and-Onboarding.md):
   manages consoles.json and checks bundled data, daemon binary, and configured
   consoles without pressing any game buttons. *)

let ( let* ) = Result.bind

let setup_usage =
  "  gamepilot setup [--config FILE]\n"
  ^ "  gamepilot setup --discover [--write] [--config FILE]\n"
  ^ "  gamepilot setup --add-switch ID --capture DEVICE [--serial PORT] \
     [--name NAME] [--watch-port PORT] [--config FILE]\n"
  ^ "  gamepilot setup --add-mgba ID [--mgba-port PORT] [--name NAME] \
     [--watch-port PORT] [--config FILE]\n"
  ^ "  gamepilot setup --remove ID [--config FILE]\n"

let usage = setup_usage ^ Doctor_command.usage
let max_port = 65535

type setup_action =
  | Show
  | Discover of { write : bool }
  | Add_switch of {
      id : string;
      name : string option;
      capture : string option;
      serial : string option;
      watch_port : int option;
    }
  | Add_mgba of {
      id : string;
      name : string option;
      port : int;
      watch_port : int option;
    }
  | Remove of string

type setup_flags = { config : string option; action : setup_action }

let parse_port ~flag raw =
  match int_of_string_opt raw with
  | Some n when n > 0 && n <= max_port -> Ok n
  | _ ->
      Error
        (Printf.sprintf "%s expects a port in 1..%d, got %s" flag max_port raw)

let set_name action name =
  match action with
  | Add_switch s -> Ok (Add_switch { s with name = Some name })
  | Add_mgba m -> Ok (Add_mgba { m with name = Some name })
  | Show | Discover _ | Remove _ ->
      Error "--name requires --add-switch or --add-mgba"

let set_capture action capture =
  match action with
  | Add_switch s -> Ok (Add_switch { s with capture = Some capture })
  | _ -> Error "--capture requires --add-switch"

let set_serial action serial =
  match action with
  | Add_switch s -> Ok (Add_switch { s with serial = Some serial })
  | _ -> Error "--serial requires --add-switch"

let set_port action raw =
  match action with
  | Add_mgba m ->
      let* port = parse_port ~flag:"--mgba-port" raw in
      Ok (Add_mgba { m with port })
  | _ -> Error "--mgba-port requires --add-mgba"

let set_watch_port action raw =
  match action with
  | Add_switch s ->
      let* port = parse_port ~flag:"--watch-port" raw in
      Ok (Add_switch { s with watch_port = Some port })
  | Add_mgba m ->
      let* port = parse_port ~flag:"--watch-port" raw in
      Ok (Add_mgba { m with watch_port = Some port })
  | Show | Discover _ | Remove _ ->
      Error "--watch-port requires --add-switch or --add-mgba"

let add_switch_action id =
  Add_switch
    { id; name = None; capture = None; serial = None; watch_port = None }

let add_mgba_action id =
  Add_mgba
    {
      id;
      name = None;
      port = Console_config.default_mgba_port;
      watch_port = None;
    }

let rec parse_setup f = function
  | [] -> Ok f
  | "--config" :: p :: rest -> parse_setup { f with config = Some p } rest
  | "--discover" :: rest ->
      parse_setup { f with action = Discover { write = false } } rest
  | "--write" :: rest -> (
      match f.action with
      | Discover _ ->
          parse_setup { f with action = Discover { write = true } } rest
      | _ -> Error "--write requires --discover")
  | "--add-switch" :: id :: rest ->
      parse_setup { f with action = add_switch_action id } rest
  | "--add-mgba" :: id :: rest ->
      parse_setup { f with action = add_mgba_action id } rest
  | "--remove" :: id :: rest -> parse_setup { f with action = Remove id } rest
  | "--name" :: v :: rest ->
      let* action = set_name f.action v in
      parse_setup { f with action } rest
  | "--capture" :: v :: rest ->
      let* action = set_capture f.action v in
      parse_setup { f with action } rest
  | "--serial" :: v :: rest ->
      let* action = set_serial f.action v in
      parse_setup { f with action } rest
  | "--mgba-port" :: v :: rest ->
      let* action = set_port f.action v in
      parse_setup { f with action } rest
  | "--watch-port" :: v :: rest ->
      let* action = set_watch_port f.action v in
      parse_setup { f with action } rest
  | a :: _ -> Error ("setup: unknown argument " ^ a)

let print_consoles path consoles =
  Printf.printf "Config: %s\n" path;
  match consoles with
  | [] -> print_endline "Consoles: (none configured)"
  | _ ->
      print_endline "Consoles:";
      List.iter
        (fun c -> Printf.printf "  - %s\n" (Console_config.describe c))
        consoles

let save_console ~path c =
  if not (Console_config.valid_id c.Console_config.id) then
    Error ("console id " ^ c.id ^ " must use lowercase letters, digits, - or _")
  else
    let* existing = Console_config.load ~path () in
    let updated = Console_config.upsert existing c in
    let* () = Console_config.save ~path updated in
    Printf.printf "Saved %s to %s\n" (Console_config.describe c) path;
    Ok 0

let print_discovered ~serials ~captures =
  print_endline "Detected serial ports:";
  (match serials with
  | [] -> print_endline "  (none)"
  | _ -> List.iter (fun s -> Printf.printf "  - %s\n" s) serials);
  print_endline "Detected capture devices:";
  match captures with
  | [] -> print_endline "  (none)"
  | _ ->
      List.iter
        (fun (c : Console_config.Device_discovery.capture_device) ->
          Printf.printf "  - index=%s  %s (%s)\n" c.index c.name c.device_id)
        captures

let suggested_console (id, name, serial, capture) : Console_config.console =
  { id; name; backend = Switch { serial; capture }; watch_port = None }

let run_discover ~path ~write =
  let serials = Console_config.Device_discovery.discover_serial_ports () in
  let captures = Console_config.Device_discovery.discover_capture_devices () in
  print_discovered ~serials ~captures;
  let suggested =
    Console_config.Device_discovery.suggest_consoles ~serials ~captures
    |> List.map suggested_console
  in
  if suggested = [] then (
    print_endline "No Switch hardware detected.";
    Ok 0)
  else if write then (
    let* existing = Console_config.load ~path () in
    let updated = List.fold_left Console_config.upsert existing suggested in
    let* () = Console_config.save ~path updated in
    Printf.printf "Wrote %d console(s) to %s:\n" (List.length suggested) path;
    List.iter
      (fun c -> Printf.printf "  - %s\n" (Console_config.describe c))
      suggested;
    Ok 0)
  else (
    print_endline "";
    print_endline "Suggested consoles (re-run with --discover --write to save):";
    List.iter
      (fun c -> Printf.printf "  - %s\n" (Console_config.describe c))
      suggested;
    Ok 0)

let print_setup_help () =
  print_endline
    "\n\
     Auto-discover connected Switch hardware:\n\
    \  gamepilot setup --discover [--write]\n\
     Or add manually:\n\
    \  gamepilot setup --add-switch console-a --name \"Console A\" --capture \
     <DEVICE> [--serial <PORT>] [--watch-port 47910]\n\
    \  gamepilot setup --add-mgba mgba --name \"mGBA\" [--mgba-port 47810] \
     [--watch-port 47911]\n\
     Then verify with: gamepilot doctor"

let run_setup f =
  let path = Option.value f.config ~default:(Console_config.default_path ()) in
  match f.action with
  | Show ->
      let* consoles = Console_config.load ~path () in
      print_consoles path consoles;
      print_setup_help ();
      Ok 0
  | Discover { write } -> run_discover ~path ~write
  | Add_switch { capture = None; _ } ->
      Error "--add-switch requires --capture DEVICE"
  | Add_switch { id; name; capture = Some capture; serial; watch_port } ->
      let name = Option.value name ~default:id in
      save_console ~path
        { id; name; backend = Switch { serial; capture }; watch_port }
  | Add_mgba { id; name; port; watch_port } ->
      let name = Option.value name ~default:id in
      save_console ~path { id; name; backend = Mgba { port }; watch_port }
  | Remove id ->
      let* existing = Console_config.load ~path () in
      let updated, removed = Console_config.remove existing id in
      if not removed then Error ("console " ^ id ^ " is not configured")
      else
        let* () = Console_config.save ~path updated in
        Printf.printf "Removed %s from %s\n" id path;
        Ok 0

let main_setup args =
  let* f = parse_setup { config = None; action = Show } args in
  run_setup f

let main_doctor = Doctor_command.main
