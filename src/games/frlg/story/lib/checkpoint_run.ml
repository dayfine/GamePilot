open Frlg_readers
module A = Frlg_actions

type options = {
  state : string option;
  party : A.Party_roster.t option;
  center : string option;
  grind_cap : int option;
  gait : Frlg_overworld.Route_legs.gait;
  end_check_only : bool;
  log : string -> unit;
}

let maps_dir = "third_party/PokemonSimulation/data/games/frlg/maps"

let load_rock_stairs () =
  let asset = Frlg_overworld.Rock_stairs.asset in
  match Frlg_repo_files.Repo_files.locate asset with
  | Some file -> Frlg_overworld.Rock_stairs.load file
  | None -> Error (asset ^ " not found from the working directory")

let load_all dir =
  let load name = Grid_maps.Map_file.load_runtime ~maps_dir:dir name in
  let rec all acc = function
    | [] -> Ok (List.rev acc)
    | name :: rest -> Result.bind (load name) (fun m -> all (m :: acc) rest)
  in
  let world rock_stairs maps =
    Frlg_overworld.Frlg_steps.world ~edge_stalls:false ~rock_stairs
      (Grid_maps.Connected_maps.create maps)
  in
  let names = Grid_maps.Map_file.runtime_names ~maps_dir:dir in
  Result.bind (load_rock_stairs ()) (fun rock_stairs ->
      Result.map (world rock_stairs) (all [] names))

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
    grind_cap = options.grind_cap;
    center = options.center;
    reload = reload options.state;
    log = options.log;
  }

(* End-check only: no events, and no end position (FireRed reckons it from
   the walks, so with none it would be the start's). *)
let to_run options ~end_at (plan : Story.Plan.t) =
  if options.end_check_only then ({ plan.checkpoint with events = [] }, None)
  else (plan.checkpoint, end_at)

let capped_postconditions ~grind_cap (plan : Story.Plan.t) =
  let p = plan.postconditions in
  match grind_cap with
  | None -> (p, [])
  | Some cap ->
      let capped what = Printf.sprintf "%s (grind capped at %d)" what cap in
      let skipped_knows ({ species; moves } : Story.Plan.knows) =
        capped (Printf.sprintf "knows %s %s" species (String.concat ", " moves))
      and skipped_level ({ species; min } : Story.Plan.level) =
        capped (Printf.sprintf "level %s at least %d" species min)
      in
      ( { p with knows = []; levels = [] },
        List.map skipped_knows p.knows @ List.map skipped_level p.levels )

(* The game with the caller's own actions first (a shadow plan's). *)
let with_actions actions (game : Story.Game.t) =
  { game with game_actions = actions @ game.game_actions }

type from_event = {
  range : Story.Event_range.t;
  kept : Story.Event_states.kept;
}

type keep_event_state =
  index:int -> Story.Plan.event -> Story.Event_states.kept -> unit

let kept_money_line =
  Printf.sprintf
    "[Postcondition] the money at the checkpoint's start, kept with the \
     event's state: $%d"

let log_kept_money options money =
  Option.iter (fun m -> options.log (kept_money_line m)) money

(* The money at the checkpoint's start for a spent promise: read now, or kept
   with the event's state on a partial run. *)
let start_money options ~from_event checked =
  match from_event with
  | _ when options.end_check_only -> None
  | Some { kept; _ } ->
      log_kept_money options kept.Story.Event_states.start_money;
      kept.start_money
  | None -> Postcondition_reads.start_money ~log:options.log checked

(* Where the player stands at the first event: the checkpoint's start, or on
   a partial run where the run that kept the state reckoned them. *)
let start_pose (plan : Story.Plan.t) = function
  | Some { kept; _ } -> kept.Story.Event_states.at
  | None -> start_of plan.checkpoint

(* [on_event], and the state kept at each event reached cleanly with what
   [kept ()] says then. *)
let keeping_states ?on_event ~keep ~first (checkpoint : Story.Plan.checkpoint)
    kept =
  let tracker = Story.Event_states.tracker ~first in
  fun index progress ->
    (match keep with
    | Some keep when Story.Event_states.hear tracker index progress ->
        keep ~index (List.nth checkpoint.events index) (kept ())
    | _ -> ());
    Option.iter (fun f -> f index progress) on_event

let run ?end_at ?on_event ?(actions = []) ?from_event ?keep_event_state options
    world (plan : Story.Plan.t) =
  Option.iter (fun s -> ignore (Effects.load_state s)) options.state;
  let game =
    A.Story_game.create (config options world)
      ~start:(start_pose plan from_event)
  in
  let checkpoint, end_at = to_run options ~end_at plan in
  let checked, skipped =
    capped_postconditions ~grind_cap:options.grind_cap plan
  in
  List.iter
    (fun s ->
      options.log
        (Printf.sprintf "[Postcondition] %s %s: skipped"
           plan.checkpoint.checkpoint_id s))
    skipped;
  Effects.with_probes Screen_facts.probes (fun () ->
      let start_money = start_money options ~from_event checked in
      let observe promised =
        {
          (Postcondition_reads.observe ~log:options.log promised) with
          start_money;
        }
      in
      let events = Option.map (fun f -> f.range) from_event in
      let first =
        Option.fold ~none:0 ~some:(fun r -> r.Story.Event_range.first) events
      in
      let game = with_actions actions (A.Story_game.game game) in
      let on_event =
        keeping_states ?on_event ~keep:keep_event_state ~first checkpoint
          (fun () -> { Story.Event_states.start_money; at = game.position () })
      in
      Story.Runner.run ?end_at ~end_state:(checked, observe) ~on_event ?events
        game checkpoint)
