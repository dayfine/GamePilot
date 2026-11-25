let ( let* ) = Result.bind
let fragments_asset = "src/games/frlg/fragments/fragments.json"

let read_fragments () =
  match Frlg_repo_files.Repo_files.locate fragments_asset with
  | None -> Error (fragments_asset ^ " not found from the working directory")
  | Some path ->
      Result.bind
        (Frlg_repo_files.Json_file.read path)
        (Checkpoints_expand.Fragment_table.parse ~source:"fragments.json")

let fragments = lazy (read_fragments ())

let decode ~source json =
  let* fragments = Lazy.force fragments in
  let* places = Frlg_places.Place_table.load () in
  let* json =
    Checkpoints_expand.Fragment_calls.expand fragments
      (Frlg_places.Place_table.resolve places)
      ~source json
  in
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
