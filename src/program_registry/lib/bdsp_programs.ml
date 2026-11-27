open Descriptor

let game =
  {
    game_id = "bdsp";
    game_name = "Pokémon Brilliant Diamond / Shining Pearl";
    delete_save_icons = [];
    switch = None;
  }

let max_underground_cycles = 999
let max_underground_slates = 99

let mode_values =
  [
    "farm";
    "check-bag";
    "check-map";
    "step-refresh";
    "step-read-map";
    "step-route-one";
    "step-dig-one";
  ]

let mode_option : Run_options.declared =
  {
    key = "mode";
    value = Run_options.One_of mode_values;
    presence = Run_options.Default "farm";
    doc =
      "farm: full Grand Underground shard loop; check-bag: inspect Treasures \
       pocket; check-map: capture full-sized map (Y -> A); step-refresh / \
       step-read-map / step-route-one / step-dig-one: isolated single-step \
       verification modes.";
  }

let door_option : Run_options.declared =
  {
    key = "door";
    value = Run_options.One_of [ "south"; "north" ];
    presence = Run_options.Default "south";
    doc = "Starting Hideaway doorway for step-route-one (south or north).";
  }

let cycles_option : Run_options.declared =
  {
    key = "cycles";
    value = Run_options.Int_range (1, max_underground_cycles);
    presence = Run_options.Default "15";
    doc = "Number of Hideaway doorway-refresh cycles to run in farm mode.";
  }

let slates_option : Run_options.declared =
  {
    key = "slates";
    value = Run_options.Int_range (1, max_underground_slates);
    presence = Run_options.Default "14";
    doc =
      "Ramanas Park slate budget (1 Shard L or 3 Shard S per slate); stops \
       once reached.";
  }

let underground_options =
  [ mode_option; door_option; cycles_option; slates_option ]

let underground =
  {
    id = "bdsp.underground";
    game;
    name = "Grand Underground";
    category = Farming;
    description =
      "Farms Mysterious Shards and treasures in the Grand Underground.";
    doc = "docs/guide/bdsp.underground.md";
    checkpoints = Some "src/games/pokemon/bdsp/programs/underground/plans";
    backends = [ Switch ];
    viewport = Native;
    rules = Bdsp;
    options = underground_options;
  }

type static_rng_bounds = {
  nature_count : int;
  delay_min_ms : int;
  delay_max_ms : int;
  max_attempts : int;
  timeout_min_s : int;
  timeout_max_s : int;
}

let static_bounds =
  {
    nature_count = 25;
    delay_min_ms = -5000;
    delay_max_ms = 5000;
    max_attempts = 999;
    timeout_min_s = 60;
    timeout_max_s = 3600;
  }

let static_target_values =
  List.map
    (fun (t : Bdsp_rng.Static_targets.t) -> t.id)
    Bdsp_rng.Static_targets.all

let static_nature_values =
  List.init static_bounds.nature_count (fun i ->
      String.lowercase_ascii (Bdsp_rng.Static_encounter.nature_name i))

let static_rng_options : Run_options.declared list =
  [
    {
      key = "target";
      value = Run_options.One_of static_target_values;
      presence = Run_options.Default "kyogre";
      doc = "Static legendary target species slug from Static_targets.all.";
    };
    {
      key = "shiny";
      value = Run_options.One_of [ "any"; "star"; "square" ];
      presence = Run_options.Default "any";
      doc = "Required shiny class: any, star, or square.";
    };
    {
      key = "delay_ms";
      value =
        Run_options.Int_range
          (static_bounds.delay_min_ms, static_bounds.delay_max_ms);
      presence = Run_options.Default "200";
      doc =
        "Calibration offset in ms added to the timed encounter confirm press.";
    };
    {
      key = "sync";
      value = Run_options.One_of static_nature_values;
      presence = Run_options.Optional;
      doc = "Optional Synchronize lead nature (omit if not using Synchronize).";
    };
    {
      key = "max_attempts";
      value = Run_options.Int_range (1, static_bounds.max_attempts);
      presence = Run_options.Default "20";
      doc = "Maximum soft-reset attempts before stopping.";
    };
    {
      key = "seed_timeout_s";
      value =
        Run_options.Int_range
          (static_bounds.timeout_min_s, static_bounds.timeout_max_s);
      presence = Run_options.Default "600";
      doc =
        "Maximum seconds to wait for 0PK pedestal seed recovery per attempt.";
    };
  ]

let static_rng =
  {
    id = "bdsp.static_rng";
    game;
    name = "Static Legendary RNG";
    category = Shiny_hunting;
    description =
      "Hunts shiny static legendaries using 0PK pedestal player-blink seed \
       recovery, in-chamber 1PK re-identification, and timed encounter \
       triggers.";
    doc = "docs/guide/bdsp.static_rng.md";
    checkpoints = Some "src/games/pokemon/bdsp/programs/static_rng/plans";
    backends = [ Switch ];
    viewport = Native;
    rules = Bdsp;
    options = static_rng_options;
  }

let all = [ underground; static_rng ]
