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
    doc = "docs/guide/bdsp/underground.md";
    checkpoints = Some "src/games/pokemon/bdsp/programs/underground/plans";
    backends = [ Switch ];
    viewport = Native;
    rules = Bdsp;
    options = underground_options;
  }

let all = [ underground ]
