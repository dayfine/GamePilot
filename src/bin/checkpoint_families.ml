(* Each family of checkpoint rules (Program_registry.rules) and its series
   library's entry points: how gamepilot run runs its series and one plan
   (--plan), how gamepilot replay checkpoint replays one plan, how its guide
   lists its checkpoints, their needs and the commands that run them, what
   gamepilot programs says a chain needs, and the readers gamepilot ctl read
   runs. Game-specific action dispatch and host-side inputs live in each game's
   series library; this file is the uniform dispatch table over
   Program_registry.rules. A program no registry entry names uses the Pokémon
   grid rules. *)

module R = Program_registry
module Grid = Frlg_series

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

let program_fields plan_dir =
  Option.fold ~none:[] ~some:R.run_fields (R.of_plan_dir plan_dir)

let viewport plan_dir (f : _ Run_flags.flags) =
  R.check_viewport (R.of_plan_dir plan_dir) f.viewport

let program_options plan_dir (f : _ Run_flags.flags) =
  R.check_options (R.of_plan_dir plan_dir) f.options

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

let grid_guide : Guide_blocks.rules_guide =
  {
    rows = Grid.Guide_tables.rows;
    needs = Grid.Guide_tables.needs;
    preflight = Grid.Guide_tables.preflight;
    commands = Guide_blocks.grid_commands;
    program_block = (fun _ _ -> None);
  }

let grid =
  {
    run_series = grid_series;
    run_checkpoint = Grid.Plan_command.live ~program_fields;
    replay_checkpoint = Grid.Plan_command.replay;
    guide = grid_guide;
    chain_needs = Grid.Chain_needs.needs;
    ctl_readers = Frlg_ctl_readers.Ctl_readers.all;
  }

let checkpoint_rows ~load_title ~plan_dir ids =
  let* rev =
    List.fold_left
      (fun acc id ->
        let* acc = acc in
        let* cp_id, title = load_title ~plan_dir id in
        let row = Printf.sprintf "| %s | %s |" cp_id (Guide_page.cell title) in
        Ok (row :: acc))
      (Ok []) ids
  in
  Ok (List.rev rev)

let switch_testing_commands ~args =
  String.concat "\n"
    [
      "# the Switch: each checkpoint once, from where the console is";
      "cd src && opam exec -- dune exec -- gamepilot run " ^ args
      ^ " --mode testing --backend switch --serial PORT --capture DEVICE \\";
      "    --watch";
    ]

let no_stated game what ~plan_dir:_ _ =
  Error (game ^ "'s plans state no " ^ what)

let switch_only_guide ~game ~load_title ?(guide_blocks = []) () :
    Guide_blocks.rules_guide =
  {
    rows = checkpoint_rows ~load_title;
    needs = no_stated game "needs";
    preflight = no_stated game "pre-flight";
    commands = (fun _ ~args -> switch_testing_commands ~args);
    program_block =
      (fun _ name ->
        Option.map (fun f -> f ()) (List.assoc_opt name guide_blocks));
  }

let run_switch_series run plan_dir args =
  let* f = Run_flags.parse_no_game_flags args in
  let* options = program_options plan_dir f in
  run ~program:(program_fields plan_dir) ~options
    ~viewport:(viewport plan_dir f) plan_dir args

let switch_only_family ~game ?checkpoint_label ~load_title ?(guide_blocks = [])
    ~run_series () =
  let label = Option.value checkpoint_label ~default:game in
  {
    run_series = run_switch_series run_series;
    run_checkpoint =
      (fun _ _ -> Error (label ^ " runs whole series only: gamepilot run"));
    replay_checkpoint =
      (fun _ _ _ -> Error (game ^ " has no checkpoint replay yet"));
    guide = switch_only_guide ~game ~load_title ~guide_blocks ();
    chain_needs = (fun _ -> Error (game ^ "'s plans state no chain needs"));
    ctl_readers = [];
  }

let plza_load_title = Plza_checkpoint_series.Checkpoint_series.load_title
let bdsp_load_title = Bdsp_checkpoint_series.Checkpoint_series.load_title

let plza =
  switch_only_family ~game:"PLZA" ~load_title:plza_load_title
    ~run_series:Plza_series.Runs.run_series ()

let plza_home =
  switch_only_family ~game:"PLZA" ~checkpoint_label:"pokemon_home.bank-plza"
    ~load_title:plza_load_title
    ~run_series:Plza_bank_home_series.Bank_home_runs.run_series ()

let plza_gifts =
  switch_only_family ~game:"PLZA" ~checkpoint_label:"plza.claim-gifts"
    ~load_title:plza_load_title
    ~guide_blocks:Plza_claim_gifts_series.Claim_gifts_runs.guide_blocks
    ~run_series:Plza_claim_gifts_series.Claim_gifts_runs.run_series ()

let bdsp_underground =
  switch_only_family ~game:"BDSP" ~load_title:bdsp_load_title
    ~run_series:Bdsp_underground_series.Underground_runs.run_series ()

let bdsp_static_rng =
  switch_only_family ~game:"BDSP" ~load_title:bdsp_load_title
    ~run_series:Bdsp_static_rng_series.Static_rng_runs.run_series ()

let bdsp_battle_catch =
  switch_only_family ~game:"BDSP" ~load_title:bdsp_load_title
    ~run_series:Bdsp_battle_catch_series.Battle_catch_runs.run_series ()

let all =
  [
    grid;
    plza;
    plza_home;
    plza_gifts;
    bdsp_underground;
    bdsp_static_rng;
    bdsp_battle_catch;
  ]

let of_rules = function
  | R.Pokemon_grid -> grid
  | R.Plza_story -> plza
  | R.Pokemon_home -> plza_home
  | R.Plza_gifts -> plza_gifts
  | R.Bdsp_underground -> bdsp_underground
  | R.Bdsp_static_rng -> bdsp_static_rng
  | R.Bdsp_battle_catch -> bdsp_battle_catch

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
