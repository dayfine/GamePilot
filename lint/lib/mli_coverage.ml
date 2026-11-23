let missing_interface (c : Config.t) files path =
  Filename.check_suffix path ".ml"
  && Source_tree.in_library_dir c path
  && not (List.mem (path ^ "i") files)

let check c files =
  List.filter (missing_interface c files) files
  |> List.map (fun path ->
         Finding.error ~check:"mli_coverage" ~path ~line:0
           "library module has no .mli")
