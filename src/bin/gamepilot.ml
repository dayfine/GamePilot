(* gamepilot run <program> [--port N] [--state PATH]
   gamepilot replay <program> <wirelog> *)

let usage =
  "usage:\n\
  \  gamepilot run start_menu_poc [--port 47900] [--state PATH]\n\
  \  gamepilot replay start_menu_poc WIRELOG\n"

let die msg =
  prerr_string msg;
  exit 2

let parse_run_flags args =
  let rec go port state = function
    | [] -> (port, state)
    | "--port" :: p :: rest -> (
        match int_of_string_opt p with
        | Some p -> go p state rest
        | None -> die ("bad --port " ^ p ^ "\n" ^ usage))
    | "--state" :: s :: rest -> go port s rest
    | a :: _ -> die ("unknown argument " ^ a ^ "\n" ^ usage)
  in
  go Handler_real.Real.default_port Frlg.Start_menu_poc.default_state args

(* Runs the program under [handle]; prints the outcome line; returns the exit
   code. *)
let run_program handle state =
  match handle (Frlg.Start_menu_poc.run ~state) with
  | outcome -> (
      print_endline (Frlg.Start_menu_poc.describe outcome);
      match outcome with Frlg.Start_menu_poc.Passed _ -> 0 | _ -> 1)
  | exception Handler.Replay.Divergence e ->
      print_endline ("start_menu_poc: DIVERGED " ^ e);
      1
  | exception Kernel.Disconnected e ->
      print_endline ("start_menu_poc: DISCONNECTED " ^ e);
      1
  | exception Kernel.Rpc_error { code; message; _ } ->
      Printf.printf "start_menu_poc: DAEMON ERROR %d %s\n" code message;
      1
  | exception Unix.Unix_error (e, f, _) ->
      Printf.printf "start_menu_poc: CONNECT FAILED %s: %s\n" f
        (Unix.error_message e);
      1

let () =
  match List.tl (Array.to_list Sys.argv) with
  | "run" :: "start_menu_poc" :: flags ->
      let port, state = parse_run_flags flags in
      exit (run_program (Handler_real.Real.run ~port) state)
  | [ "replay"; "start_menu_poc"; wirelog ] ->
      let log = Handler.Replay.log_of_file wirelog in
      exit
        (run_program (Handler.Replay.run log) Frlg.Start_menu_poc.default_state)
  | _ -> die usage
