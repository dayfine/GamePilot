open Frlg_readers
module A = Frlg_actions

type options = {
  state : string option;
  party : A.Party_roster.t;
  center : string option;
  gait : Frlg_overworld.Route_legs.gait;
  end_check_only : bool;
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
      Frlg_overworld.Frlg_steps.world ~edge_stalls:false
        (Grid_maps.Connected_maps.create maps))
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

(* End-check only: no events, and no end position (FireRed reckons it from
   the walks, so with none it would be the start's). *)
let to_run options ~end_at (plan : Story.Plan.t) =
  if options.end_check_only then ({ plan.checkpoint with events = [] }, None)
  else (plan.checkpoint, end_at)

let run ?end_at ?on_event options world (plan : Story.Plan.t) =
  Option.iter (fun s -> ignore (Effects.load_state s)) options.state;
  let game =
    A.Story_game.create (config options world) ~start:(start_of plan.checkpoint)
  in
  let checkpoint, end_at = to_run options ~end_at plan in
  let end_state =
    (plan.postconditions, Postcondition_reads.observe ~log:options.log)
  in
  Effects.with_probes Screen_facts.probes (fun () ->
      Story.Runner.run ?end_at ~end_state ?on_event (A.Story_game.game game)
        checkpoint)
