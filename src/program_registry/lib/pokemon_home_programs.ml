open Descriptor

let game =
  {
    game_id = "pokemon_home";
    game_name = "Pokémon HOME";
    delete_save_icons = [];
    switch_home = None;
  }

let plza_bank_home =
  {
    id = "pokemon_home.bank-plza";
    game;
    name = "Bank PLZA in HOME";
    category = Storage;
    description =
      "Moves the claimed gifts from the game's box into their Pokémon HOME \
       boxes and saves HOME.";
    doc = "docs/guide/pokemon_home.bank-plza.md";
    checkpoints = Some "src/games/pokemon/plza/programs/bank_home/plans";
    backends = [ Switch ];
    viewport = Native;
    rules = Pokemon_home;
    options = [];
  }

let all = [ plza_bank_home ]
