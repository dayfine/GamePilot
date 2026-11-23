let code_checks c path text =
  match Parsed_source.parse ~path text with
  | Error f -> [ f ]
  | Ok src ->
      Function_length.check c src
      @ Nesting.check c src @ Complexity.check c src
      @
      if Source_tree.in_library_dir c path then Magic_numbers.check src else []

let file_findings (c : Config.t) path =
  if Source_tree.in_test_dir c path then []
  else if Filename.check_suffix path ".ml" then
    let text = Source_tree.read path in
    File_length.check c ~path text @ code_checks c path text
  else if Filename.check_suffix path ".mli" then
    File_length.check c ~path (Source_tree.read path)
  else []

let exceptions (c : Config.t) =
  match c.exceptions_file with
  | None -> Ok ("", [])
  | Some file -> (
      match Lint_exceptions.parse (Source_tree.read file) with
      | Ok entries -> Ok (file, entries)
      | Error e -> Error (file ^ ": " ^ e)
      | exception Sys_error e -> Error e)

let run (c : Config.t) =
  let ( let* ) = Result.bind in
  let* files = Source_tree.files c in
  let* file, entries = exceptions c in
  let code_files =
    List.filter (fun f -> not (Source_tree.in_test_dir c f)) files
  in
  let dune_files =
    List.filter (fun f -> Filename.basename f = "dune") files
    |> List.map (fun f -> (f, Source_tree.read f))
  in
  let findings =
    List.concat_map (file_findings c) files
    @ Mli_coverage.check c code_files
    @ Layers.check c dune_files
  in
  Ok
    (Lint_exceptions.apply ~file entries findings
    |> List.sort (fun (a : Finding.t) b ->
           compare (a.path, a.line) (b.path, b.line)))
