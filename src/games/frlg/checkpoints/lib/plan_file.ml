let ( let* ) = Result.bind

let decode ~source json =
  let* places = Frlg_places.Place_table.load () in
  let* json =
    Checkpoints_expand.Place_routes.expand
      (Frlg_places.Place_table.routes places)
      ~source json
  in
  Checkpoints.Plan_decode.decode ~source json

let load path =
  Result.bind
    (Frlg_repo_files.Json_file.read path)
    (decode ~source:(Filename.basename path))
