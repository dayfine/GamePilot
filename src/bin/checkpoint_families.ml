(* Each family of checkpoint rules (Program_registry.rules) and its library's
   entry points: how gamepilot run runs its series and one plan (--plan),
   how gamepilot replay checkpoint replays one plan, how its guide lists its checkpoints,
   their needs and the commands that run them, and what gamepilot programs
   says a chain needs; and the readers gamepilot ctl read runs. The one place
   under bin/ that picks a family; a program no registry entry names is over
   the Pokémon grid rules. *)

module R = Program_registry
module Grid = Frlg_series
module Plza = Plza_series.Runs

let ( let* ) = Result.bind

type t = {
  run_series : string -> string list -> (int, string) result;
      (** The series from a plan folder, with the command's args. *)
  run_checkpoint : string -> string list -> (int, string) result;
      (** One plan file on a running daemon, with the command's flags. *)
  replay_checkpoint : string -> string -> string list -> (int, string) result;
      (** One plan file replayed from a wire log. *)
  guide : Guide_blocks.rules_guide;
  chain_needs : string -> (string, string) result;
      (** What a plan folder's chain needs of the save, in one line (gamepilot
          programs). *)
  ctl_readers : Ctl_script.reader list;  (** What gamepilot ctl read runs. *)
}

(* run.json's program fields for a plan folder; none for no program. *)
let program_fields plan_dir =
  Option.fold ~none:[] ~some:R.run_fields (R.of_plan_dir plan_dir)

(* The Switch daemons' --viewport: the program's, which a --viewport given
   must match. *)
let viewport plan_dir (f : _ Run_flags.flags) =
  R.check_viewport (R.of_plan_dir plan_dir) f.viewport

(* The program's --options, checked against its declaration before anything
   runs. *)
let program_options plan_dir (f : _ Run_flags.flags) =
  R.check_options (R.of_plan_dir plan_dir) f.options

(* The game's Switch HOME tile colour for a plan folder, when known. *)
let home_tile plan_dir =
  Option.bind (R.of_plan_dir plan_dir) (fun (p : R.t) ->
      Option.map (fun (s : R.switch) -> s.home_tile) p.game.switch)

let grid_series plan_dir args =
  let* f = Pokemon_flags.parse Pokemon_flags.defaults args in
  let* options = program_options plan_dir f in
  Grid.Run_command.run_grid
    ~program:
      {
        fields = program_fields;
        viewport = viewport plan_dir f;
        home_tile = home_tile plan_dir;
        options;
      }
    plan_dir f

(* The Pokémon grid rules' guide. *)
let grid_guide : Guide_blocks.rules_guide =
  {
    rows = Grid.Guide_tables.rows;
    needs = Grid.Guide_tables.needs;
    preflight = Grid.Guide_tables.preflight;
    commands = Guide_blocks.grid_commands;
    program_block = (fun _ _ -> None);
  }

(* The Pokémon grid rules' entry points. *)
let grid =
  {
    run_series = grid_series;
    run_checkpoint = Grid.Plan_command.live ~program_fields;
    replay_checkpoint = Grid.Plan_command.replay;
    guide = grid_guide;
    chain_needs = Grid.Chain_needs.needs;
    ctl_readers = Frlg_ctl_readers.Ctl_readers.all;
  }

let plza_series plan_dir args =
  let* f = Plza_checkpoint_series.Flags.parse args in
  let* options = program_options plan_dir f in
  Plza.run_series ~program:(program_fields plan_dir) ~options
    ~viewport:(viewport plan_dir f) plan_dir args

let no_stated what ~plan_dir:_ _ = Error ("PLZA's plans state no " ^ what)

let plza_guide : Guide_blocks.rules_guide =
  {
    rows = Plza_checkpoint_series.Guide_tables.rows;
    needs = no_stated "needs";
    preflight = no_stated "pre-flight";
    commands =
      (fun _ ~args -> Plza_checkpoint_series.Guide_tables.commands ~args);
    program_block = (fun _ _ -> None);
  }

(* PLZA's story rules' entry points: a series of whole checkpoints on the
   Switch; no plan runs alone, and the plans state no chain needs. *)
let plza =
  {
    run_series = plza_series;
    run_checkpoint =
      (fun _ _ -> Error "PLZA runs whole series only: gamepilot run");
    replay_checkpoint = (fun _ _ _ -> Error "PLZA has no checkpoint replay yet");
    guide = plza_guide;
    chain_needs = (fun _ -> Error "PLZA's plans state no chain needs");
    ctl_readers = [];
  }

let plza_home_series plan_dir args =
  let* f = Plza_checkpoint_series.Flags.parse args in
  let* options = program_options plan_dir f in
  let* catalog = Plza_gift_inputs.catalog () in
  let* moves =
    Plza_bank_home.Catalog_moves.of_catalog
      ~today:(Plza_gift_inputs.today ())
      catalog
  in
  Plza_bank_home_series.Bank_home_runs.run_series ~moves
    ~program:(program_fields plan_dir) ~options ~viewport:(viewport plan_dir f)
    plan_dir args

(* PLZA's Pokémon HOME rules' entry points: plans over PLZA's rules, run from
   the Switch's HOME menu in Pokémon HOME, whole checkpoints on the Switch, as
   the story's; their guide is the story's. *)
let plza_home =
  {
    plza with
    run_series = plza_home_series;
    run_checkpoint =
      (fun _ _ ->
        Error "pokemon_home.bank-plza runs whole series only: gamepilot run");
    ctl_readers = [];
  }

let plza_gifts_series plan_dir args =
  let* f = Plza_checkpoint_series.Flags.parse args in
  let* options = program_options plan_dir f in
  let* inputs = Plza_gift_inputs.inputs options in
  Plza_claim_gifts_series.Claim_gifts_runs.run_series inputs
    ~program:(program_fields plan_dir) ~options ~viewport:(viewport plan_dir f)
    plan_dir args

(* The gifts block: plza.claim-gifts' catalog. *)
let gifts_block _ = function
  | "gifts" -> Some (Plza_gift_inputs.gifts_block ())
  | _ -> None

(* PLZA's Mystery Gift rules' entry points: plans over PLZA's rules, run from
   the game's main menu, whole checkpoints on the Switch, as the story's; their
   guide is the story's, with the gift catalog's block. *)
let plza_gifts =
  {
    plza with
    run_series = plza_gifts_series;
    run_checkpoint =
      (fun _ _ ->
        Error "plza.claim-gifts runs whole series only: gamepilot run");
    guide = { plza_guide with program_block = gifts_block };
  }

let run_bdsp_static_rng ~log ~picture ~options =
  match Bdsp_static_rng_run.load_templates () with
  | Error msg ->
      Error (Engine_run.Failure.cause ~repeats:false "static_rng_templates" msg)
  | Ok templates ->
      let passed, line =
        Bdsp_static_rng.Static_rng.run ~picture ~templates ~options ()
      in
      log line;
      if passed then Ok ()
      else
        Error (Engine_run.Failure.cause ~repeats:true "static_rng_failed" line)

let run_bdsp_action ~log ~picture ~options = function
  | Bdsp_rules.Action.Save_game -> (
      match Bdsp_actions.Save_game.save_game ~log ~picture () with
      | Ok () -> Ok ()
      | Error msg ->
          Error (Engine_run.Failure.cause ~repeats:true "save_game_failed" msg))
  | Bdsp_rules.Action.Static_rng -> run_bdsp_static_rng ~log ~picture ~options

let bdsp_series plan_dir args =
  let* f = Bdsp_checkpoint_series.Flags.parse args in
  let* options = program_options plan_dir f in
  Bdsp_checkpoint_series.Checkpoint_series.run_series
    {
      check_plans = (fun _ -> Ok ());
      daemon_flags = [];
      initial_screen = (fun _ -> Switch.Initial_screen.In_game_or_resume None);
      run_action = run_bdsp_action;
    }
    ~program_fields:(program_fields plan_dir) ~options
    ~viewport:(viewport plan_dir f) plan_dir args

let no_bdsp_stated what ~plan_dir:_ _ = Error ("BDSP's plans state no " ^ what)

let bdsp_guide : Guide_blocks.rules_guide =
  {
    rows = Bdsp_checkpoint_series.Guide_tables.rows;
    needs = no_bdsp_stated "needs";
    preflight = no_bdsp_stated "pre-flight";
    commands =
      (fun _ ~args -> Bdsp_checkpoint_series.Guide_tables.commands ~args);
    program_block = (fun _ _ -> None);
  }

(* BDSP's rules' entry points: a series of whole checkpoints on the Switch. *)
let bdsp =
  {
    run_series = bdsp_series;
    run_checkpoint =
      (fun _ _ -> Error "BDSP runs whole series only: gamepilot run");
    replay_checkpoint = (fun _ _ _ -> Error "BDSP has no checkpoint replay yet");
    guide = bdsp_guide;
    chain_needs = (fun _ -> Error "BDSP's plans state no chain needs");
    ctl_readers = [];
  }

let all = [ grid; plza; plza_home; plza_gifts; bdsp ]

let of_rules = function
  | R.Pokemon_grid -> grid
  | R.Plza_story -> plza
  | R.Pokemon_home -> plza_home
  | R.Plza_gifts -> plza_gifts
  | R.Bdsp -> bdsp

let of_program (p : R.t option) =
  of_rules (match p with Some p -> p.rules | None -> R.Pokemon_grid)

let guide (p : R.t) = (of_program (Some p)).guide

let main plan_dir args =
  (of_program (R.of_plan_dir plan_dir)).run_series plan_dir args

(* gamepilot run --plan's usage: the grid rules', the only family that runs a
   plan file alone. *)
let usage = Grid.Plan_command.usage

(* gamepilot run's usage: the grid rules' flags. *)
let run_usage = Pokemon_flags.usage
let of_plan_file plan = of_program (R.of_plan_dir (Filename.dirname plan))
let checkpoint plan args = (of_plan_file plan).run_checkpoint plan args

let replay_checkpoint wirelog plan args =
  (of_plan_file plan).replay_checkpoint wirelog plan args

(* Every family's readers: gamepilot ctl names no program. *)
let ctl_readers = List.concat_map (fun f -> f.ctl_readers) all

let ctl_reader name =
  List.find_opt (fun (r : Ctl_script.reader) -> r.name = name) ctl_readers
