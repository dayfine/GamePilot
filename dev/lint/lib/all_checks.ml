let library_code_checks c path src =
  if not (Source_tree.in_library_dir c path) then []
  else
    Magic_numbers.check src @ Flat_constants.check c src
    @ Variant_with_suffix.check_implementation src
    @ if Direct_io.in_scope path then Direct_io.check src else []

let code_checks c path text =
  match Parsed_source.parse ~path text with
  | Error f -> [ f ]
  | Ok src ->
      Function_length.check c src
      @ Nesting.check c src @ Complexity.check c src
      @ library_code_checks c path src
      @
      if Source_tree.under_no_exceptions_root c path then
        No_exceptions.check src
      else []

let interface_checks c path text =
  if not (Source_tree.in_library_dir c path) then []
  else
    match Parsed_source.parse_interface ~path text with
    | Error f -> [ f ]
    | Ok _ ->
        Variant_with_suffix.check_interface ~path text
        @ Ambiguous_return.check ~path text
        @
        if Source_tree.under_interface_docs_root c path then
          Interface_docs.check ~path text
        else []

let test_checks path text =
  match Parsed_source.parse ~path text with
  | Error f -> [ f ]
  | Ok src -> Text_assertions.check src

let file_findings (c : Config.t) path =
  if Source_tree.in_test_dir c path then
    if Filename.check_suffix path ".ml" then
      test_checks path (Source_tree.read path)
    else []
  else if Filename.check_suffix path ".ml" then
    let text = Source_tree.read path in
    File_length.check c ~path text @ code_checks c path text
  else if Filename.check_suffix path ".mli" then
    let text = Source_tree.read path in
    File_length.check c ~path text
    @ Doc_listing.check c ~path text
    @ interface_checks c path text
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
    @ Never_links.check c dune_files
  in
  Ok
    (Lint_exceptions.apply ~file entries findings
    |> List.sort (fun (a : Finding.t) b ->
           compare (a.path, a.line) (b.path, b.line)))
