open Ocaml_lint

let usage =
  "usage: main CONFIG\n\
   Runs every check configured in CONFIG; paths are relative to the working \
   directory."

let fail message =
  prerr_endline message;
  exit 2

let load_config file =
  match Config.parse (In_channel.with_open_bin file In_channel.input_all) with
  | Ok c -> c
  | Error e -> fail (file ^ ": " ^ e)

let report findings =
  List.iter (fun f -> print_endline (Finding.to_string f)) findings;
  let is_error (f : Finding.t) = f.severity = Error in
  match List.length (List.filter is_error findings) with
  | 0 -> print_endline "ocaml_lint: ok"
  | n ->
      Printf.printf "ocaml_lint: %d finding(s)\n" n;
      exit 1

let () =
  match Sys.argv with
  | [| _; file |] -> (
      match All_checks.run (load_config file) with
      | Ok findings -> report findings
      | Error e -> fail e)
  | _ -> fail usage
