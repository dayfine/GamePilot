open Descriptor

let game =
  {
    game_id = "bdsp";
    game_name = "Pokémon Brilliant Diamond / Shining Pearl";
    delete_save_icons = [];
    switch = None;
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
    timeout_min_s = 30;
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
      key = "munchlax_timeout_s";
      value =
        Run_options.Int_range
          (static_bounds.timeout_min_s, static_bounds.timeout_max_s);
      presence = Run_options.Default "300";
      doc =
        "Maximum seconds to wait for Munchlax boot-seed recovery per attempt.";
    };
  ]

let static_rng =
  {
    id = "bdsp.static_rng";
    game;
    name = "Static Legendary RNG";
    category = Shiny_hunting;
    description =
      "Hunts shiny static legendaries using Munchlax boot-seed recovery, \
       in-chamber 1PK re-identification, and timed encounter triggers.";
    doc = "docs/guide/bdsp.static_rng.md";
    checkpoints = Some "src/games/pokemon/bdsp/programs/static_rng/plans";
    backends = [ Switch ];
    viewport = Native;
    rules = Bdsp;
    options = static_rng_options;
  }

let all = [ static_rng ]
