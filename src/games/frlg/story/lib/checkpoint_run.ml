open Frlg_readers
module A = Frlg_actions

type options = {
  state : string option;
  party : A.Party_roster.t;
  center : string option;
  gait : Frlg_overworld.Route_legs.gait;
  log : string -> unit;
}

let maps_dir = "third_party/PokemonSimulation/data/games/frlg/maps"

let load_all dir =
  let load name = Grid_maps.Map_file.load_runtime ~maps_dir:dir name in
  let rec all acc = function
    | [] -> Ok (List.rev acc)
    | name :: rest -> Result.bind (load name) (fun m -> all (m :: acc) rest)
  in
  Result.map
    (fun maps ->
      Frlg_overworld.Frlg_steps.world (Grid_maps.Connected_maps.create maps))
    (all [] (Grid_maps.Map_file.runtime_names ~maps_dir:dir))

let load_world () =
  match Frlg_repo_files.Repo_files.locate maps_dir with
  | None -> Error (maps_dir ^ " not found from the working directory")
  | Some dir -> load_all dir

let check_plan (plan : Story.Plan.t) =
  match (plan.game, Grid_maps.Json_field.find "menu" plan.execution) with
  | "frlg", (None | Some (`String "full")) -> Ok ()
  | "frlg", Some menu ->
      Error ("execution.menu " ^ Yojson.Safe.to_string menu ^ " is not \"full\"")
  | game, _ -> Error ("the plan is for " ^ game ^ ", not frlg")

let start_of (checkpoint : Story.Plan.checkpoint) =
  match checkpoint.start with
  | Some (Grid { map; tiles = [ tile ]; facing }) ->
      Some { Story.Pose.at_map = map; at_tile = tile; faces = facing }
  | _ -> None

let probes =
  let all =
    A.Scene_looks.probes @ Party_menu.probes @ Bag_screen.probes
    @ Money_box.probes
  in
  List.fold_left
    (fun kept (p : Wire.probe_spec) ->
      if List.exists (fun (k : Wire.probe_spec) -> k.id = p.id) kept then kept
      else kept @ [ p ])
    [] all

let reload state () =
  match state with
  | Some path ->
      ignore (Effects.load_state path);
      Ok ()
  | None ->
      Error
        (Story.Failure.cause ~repeats:true "no_state" "no start state to reload")

let config options world : A.Story_game.config =
  {
    world;
    gait = options.gait;
    flee = Flee_wild.flee ~log:options.log;
    flags = (fun _ -> false);
    party = options.party;
    center = options.center;
    reload = reload options.state;
    log = options.log;
  }

let run options world (plan : Story.Plan.t) =
  Option.iter (fun s -> ignore (Effects.load_state s)) options.state;
  ignore (Effects.subscribe probes);
  let game =
    A.Story_game.create (config options world) ~start:(start_of plan.checkpoint)
  in
  Story.Runner.run (A.Story_game.game game) plan.checkpoint
