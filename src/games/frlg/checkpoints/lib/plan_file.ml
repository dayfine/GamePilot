let ( let* ) = Result.bind

let decode ~source json =
  let* fragments = Frlg_fragments.Fragment_table.load () in
  let* json = Frlg_fragments.Fragment_calls.expand fragments ~source json in
  let* places = Frlg_places.Place_table.load () in
  let* json = Frlg_places.Place_targets.expand places ~source json in
  Checkpoints.Plan_decode.decode ~source json

let load path =
  Result.bind
    (Frlg_repo_files.Json_file.read path)
    (decode ~source:(Filename.basename path))
