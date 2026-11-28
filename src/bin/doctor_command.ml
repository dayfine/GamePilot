(* gamepilot doctor (docs/design/Release-and-Onboarding.md):
   checks bundled data, daemon binary, and configured consoles without pressing
   any game buttons. *)

let ( let* ) = Result.bind

let usage =
  "  gamepilot doctor [--console ID] [--daemon PATH] [--config FILE]\n"

type doctor_flags = {
  console : string option;
  daemon : string option;
  config : string option;
}

let rec parse_doctor f = function
  | [] -> Ok f
  | "--console" :: id :: rest -> parse_doctor { f with console = Some id } rest
  | "--daemon" :: p :: rest -> parse_doctor { f with daemon = Some p } rest
  | "--config" :: p :: rest -> parse_doctor { f with config = Some p } rest
  | a :: _ -> Error ("doctor: unknown argument " ^ a)

let check_line ~ok label detail =
  Printf.printf "[%s] %-16s %s\n" (if ok then "PASS" else "FAIL") label detail;
  ok

let check_switch_serial name port capture =
  let exists = Sys.win32 || Sys.file_exists port in
  let detail =
    if exists then
      Printf.sprintf "%s (switch, serial=%s, capture=%s)" name port capture
    else
      Printf.sprintf "%s (serial port %s not found; capture=%s)" name port
        capture
  in
  (exists, detail)

let check_console (c : Console_config.console) =
  let label = "console:" ^ c.id in
  match c.backend with
  | Switch { serial = Some port; capture } ->
      let ok, detail = check_switch_serial c.name port capture in
      check_line ~ok label detail
  | Switch { serial = None; capture } ->
      check_line ~ok:true label
        (Printf.sprintf "%s (switch, capture=%s, no serial)" c.name capture)
  | Mgba { port } ->
      check_line ~ok:true label
        (Printf.sprintf "%s (mgba, port=%d)" c.name port)

let selected_consoles consoles = function
  | None -> Ok consoles
  | Some id -> (
      match Console_config.find consoles id with
      | Some c -> Ok [ c ]
      | None -> Error ("unknown console " ^ id))

let main args =
  let* f = parse_doctor { console = None; daemon = None; config = None } args in
  let path = Option.value f.config ~default:(Console_config.default_path ()) in
  let* consoles = Console_config.load ~path () in
  let* targets = selected_consoles consoles f.console in
  let sample_plan =
    "src/games/pokemon/frlg/programs/supplies/plans/su-01.plan.json"
  in
  let data_ok =
    match Repo_io.Repo_files.locate sample_plan with
    | Some found -> check_line ~ok:true "bundled data" found
    | None ->
        check_line ~ok:false "bundled data"
          "plans/assets not found (set GAMEPILOT_DATA or run from release \
           folder)"
  in
  let daemon =
    Option.value f.daemon ~default:(Repo_io.Repo_files.default_daemon ())
  in
  let daemon_ok =
    if Sys.file_exists daemon then check_line ~ok:true "daemon" daemon
    else
      check_line ~ok:false "daemon"
        (daemon ^ " not found (build daemon or pass --daemon PATH)")
  in
  let consoles_ok =
    match targets with
    | [] ->
        Printf.printf
          "[WARN] %-16s none configured in %s (run: gamepilot setup)\n"
          "consoles" path;
        true
    | _ -> List.fold_left (fun acc c -> check_console c && acc) true targets
  in
  Ok (if data_ok && daemon_ok && consoles_ok then 0 else 1)
