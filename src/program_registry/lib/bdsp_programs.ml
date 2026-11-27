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

type catch_bounds = {
  max_slot : int;
  max_move : int;
  floor_min_pct : int;
  floor_max_pct : int;
  max_balls : int;
  min_turns : int;
  max_turns : int;
  pocket_bound : int;
  max_row : int;
}

let catch_b =
  {
    max_slot = 6;
    max_move = 4;
    floor_min_pct = 15;
    floor_max_pct = 80;
    max_balls = 99;
    min_turns = 10;
    max_turns = 200;
    pocket_bound = 5;
    max_row = 20;
  }

let int_opt key lo hi default doc : Run_options.declared =
  {
    key;
    value = Run_options.Int_range (lo, hi);
    presence = Run_options.Default default;
    doc;
  }

let battle_catch_options : Run_options.declared list =
  [
    {
      key = "target";
      value =
        Run_options.One_of
          [ "groudon"; "kyogre"; "latios"; "latias"; "mewtwo"; "generic" ];
      presence = Run_options.Default "groudon";
      doc = "Target encounter label for logs and policy defaults.";
    };
    {
      key = "ball";
      value =
        Run_options.One_of
          [ "luxury"; "ultra"; "timer"; "dusk"; "premier"; "master" ];
      presence = Run_options.Default "luxury";
      doc = "Poké Ball type to throw.";
    };
    int_opt "lead_slot" 1 catch_b.max_slot "1"
      "1-based party slot sent out at battle start.";
    int_opt "sleep_slot" 0 catch_b.max_slot "1"
      "1-based party slot of Sleep user (0 disables status).";
    int_opt "sleep_move" 1 catch_b.max_move "3"
      "1-based move slot of the Sleep move.";
    int_opt "false_swipe_slot" 0 catch_b.max_slot "1"
      "1-based party slot of False Swipe user (0 disables).";
    int_opt "false_swipe_move" 1 catch_b.max_move "2"
      "1-based move slot of False Swipe.";
    int_opt "setup_slot" 0 catch_b.max_slot "0"
      "Optional 1-based party slot for stat-boosting setup (0 disables).";
    int_opt "setup_move" 1 catch_b.max_move "4"
      "1-based move slot of the setup move (e.g. Swords Dance).";
    int_opt "setup_uses" 1 catch_b.max_slot "2"
      "Number of setup turns to execute during the foe's first sleep.";
    int_opt "chipper_slot" 0 catch_b.max_slot "0"
      "Optional 1-based party slot of tank/bruiser heavy-chipper (0 disables).";
    int_opt "chipper_move" 1 catch_b.max_move "1"
      "1-based move slot of the heavy-chipper's safe neutral attack.";
    int_opt "chipper_floor_pct" catch_b.floor_min_pct catch_b.floor_max_pct "30"
      "Stop heavy-chipping once foe HP is at or below this percent.";
    int_opt "wall_slot" 0 catch_b.max_slot "6"
      "Optional 1-based party slot of defensive wall (0 disables).";
    int_opt "wall_heal_move" 0 catch_b.max_move "0"
      "Optional 1-based move slot of wall recovery move (0 uses Bag heal).";
    int_opt "max_balls" 1 catch_b.max_balls "60"
      "Pause after throwing this many balls.";
    int_opt "max_turns" catch_b.min_turns catch_b.max_turns "80"
      "Pause after this many turns to guard against Struggle.";
    int_opt "ball_pocket_steps" (-catch_b.pocket_bound) catch_b.pocket_bound "0"
      "Horizontal pocket steps from initial battle Bag pocket to Poké Balls.";
    int_opt "ball_row" (-catch_b.max_row) catch_b.max_row "-1"
      "Horizontal steps in the X-button Poké Ball carousel (-1 = Left once for \
       last ball / Luxury Ball).";
    int_opt "heal_pocket_steps" (-catch_b.pocket_bound) catch_b.pocket_bound "0"
      "Horizontal pocket steps from initial battle Bag pocket to Medicine.";
    int_opt "heal_row" 0 catch_b.max_row "0"
      "0-based row of the healing item in the Medicine pocket.";
  ]

let battle_catch =
  {
    id = "bdsp.battle_catch";
    game;
    name = "Battle Catch";
    category = Shiny_hunting;
    description =
      "Catches an active BDSP wild encounter using Sleep, optional tank \
       heavy-chipping to 20–30%, False Swipe to 1 HP, and Poké Balls.";
    doc = "docs/guide/bdsp.battle_catch.md";
    checkpoints = Some "src/games/pokemon/bdsp/programs/battle_catch/plans";
    backends = [ Switch ];
    viewport = Native;
    rules = Bdsp;
    options = battle_catch_options;
  }

let all = [ underground; battle_catch ]
