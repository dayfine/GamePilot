let ( let* ) = Result.bind
let fragments_asset = "src/games/pokemon/frlg/fragments/fragments.json"

let read_fragments () =
  match Repo_io.Repo_files.locate fragments_asset with
  | None -> Error (fragments_asset ^ " not found from the working directory")
  | Some path ->
      Result.bind
        (Repo_io.Json_file.read path)
        (Engine_expand.Fragment_table.parse ~source:"fragments.json")

let fragments = lazy (read_fragments ())

let decode ~source json =
  let* fragments = Lazy.force fragments in
  let* places = Frlg_places.Place_table.load () in
  let* json =
    Engine_expand.Fragment_calls.expand fragments
      (Frlg_places.Place_table.resolve places)
      ~source json
  in
  let* json =
    Checkpoints_expand.Place_routes.expand
      (Frlg_places.Place_table.routes places)
      ~source json
  in
  Pokemon_engine.Plan_decode.decode ~source json

let load path =
  Result.bind
    (Repo_io.Json_file.read path)
    (decode ~source:(Filename.basename path))

let substitute_party ~sweeper (party : Pokemon_engine.Postconditions.party) =
  let sub s = if s = "blastoise" then sweeper else s in
  let sub_slot (s : Pokemon_engine.Postconditions.slot) =
    { s with species = sub s.species }
  in
  match party with
  | Party_in_order l ->
      Pokemon_engine.Postconditions.Party_in_order (List.map sub l)
  | Party_includes { members; slots } ->
      Party_includes
        { members = List.map sub members; slots = List.map sub_slot slots }

let apply_postcondition_options options (p : Pokemon_engine.Postconditions.t) =
  match Run_options.find options "sweeper" with
  | Some sweeper when sweeper <> "blastoise" ->
      { p with party = Option.map (substitute_party ~sweeper) p.party }
  | _ -> p
