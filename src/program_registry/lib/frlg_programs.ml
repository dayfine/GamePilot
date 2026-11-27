open Descriptor

(* FireRed's tile on HOME: its orange background and Charizard, 0.41 of the
   art; the other tiles on console B 0.05 at most (2026-11-24). RGB, each
   bound 0 to 255. *)
let fire_red_tile : Switch.Home_screen.tile_color =
  let red_from = 200 and green_from = 40 in
  let full = 255 and green_to = 170 and blue_to = 100 in
  { min = (red_from, green_from, 0); max = (full, green_to, blue_to) }

(* Each icon is 82x82 frame pixels of the 90 px icon at (90, 30) on its
   "Delete Save Data for <user>" page, 4 px in. No FireRed page was captured:
   firered's is the game list's 135 px icon (game-list-za-first.png, at (157,
   397)) scaled to 90 px (Lanczos), then cut the same way; Z-A's made so
   scores 0.0054 on its page against the reader's 0.02. *)
let game =
  {
    game_id = "frlg";
    game_name = "Pokémon FireRed/LeafGreen";
    delete_save_icons =
      [
        ("firered", "src/games/pokemon/frlg/assets/delete-save-icon-firered.png");
      ];
    switch =
      Some
        {
          title = "FireRed";
          home_tile = fire_red_tile;
          lab_panel = "PokemonFRLG:AutoStory";
        };
  }

let program ~id ~name ~category ~description ~dir ~backends ?(options = []) () =
  {
    id;
    game;
    name;
    category;
    description;
    doc = "docs/guide/" ^ id ^ ".md";
    checkpoints = Some ("src/games/pokemon/frlg/programs/" ^ dir ^ "/plans");
    backends;
    viewport = Nso_gba;
    rules = Pokemon_grid;
    options;
  }

let sweeper_option : Run_options.declared =
  {
    key = "sweeper";
    value = Text;
    presence = Default "blastoise";
    doc = "party member that leads and sweeps battles (species slug)";
  }

let sevii_story =
  program ~id:"frlg.sevii_story" ~name:"Sevii Story" ~category:Story
    ~description:"Plays the Sevii Islands story after the Cinnabar Gym."
    ~dir:"sevii_story" ~backends:[ Mgba ] ~options:[ sweeper_option ] ()

let mail_glitch_options : Run_options.declared list =
  [
    sweeper_option;
    {
      key = "depleted-move";
      value = Text;
      presence = Default "blizzard";
      doc =
        "sweeper move whose PP is drained on Route 8 so the Leppa Berry fires";
    };
  ]

let mail_glitch =
  program ~id:"frlg.mail_glitch" ~name:"Mail Glitch" ~category:Glitch_setup
    ~description:
      "Turns on the Mail Glitch against Lea & Jed on Route 16 and copies one \
       item with it."
    ~dir:"mail_glitch" ~backends:[ Mgba; Switch ] ~options:mail_glitch_options
    ()

let ace_setup =
  program ~id:"frlg.ace_setup" ~name:"ACE Setup" ~category:Glitch_setup
    ~description:
      "Sets up arbitrary code execution: the ? Mail puts species 0x0351 in Box \
       3 slot 1."
    ~dir:"ace_setup" ~backends:[ Mgba ] ()

(* The most of one item the bag holds. *)
let bag_most = 999

let ace_options : Run_options.declared list =
  [
    {
      key = "item";
      value = One_of [ "master-ball"; "luxury-ball" ];
      presence = Required;
      doc = "the item the code makes, 999 of it in the PC's item storage";
    };
    {
      key = "withdraw";
      value = Int_range (1, bag_most);
      presence = Required;
      doc = "how many of them go from the PC to the bag";
    };
  ]

let ace =
  program ~id:"frlg.ace" ~name:"ACE" ~category:Glitch_setup
    ~description:
      "Runs code typed as PC box names through species 0x0351: 999 of an item \
       in the PC, some of them to the bag."
    ~dir:"ace" ~backends:[ Mgba ] ~options:ace_options ()

let max_repels = 99

let supplies_options : Run_options.declared list =
  [
    {
      key = "retro-mail";
      value = Int_range (0, bag_most);
      presence = Default "100";
      doc = "how many Retro Mail to buy at Celadon Dept. Store 4F (0 to skip)";
    };
    {
      key = "super-repel";
      value = Int_range (0, max_repels);
      presence = Default "5";
      doc = "how many Super Repels to buy at Lavender Mart (0 to skip)";
    };
  ]

let supplies =
  program ~id:"frlg.supplies" ~name:"Supplies" ~category:Farming
    ~description:
      "Stocks what the duplication programs use: Retro Mail and Super Repels."
    ~dir:"supplies" ~backends:[ Mgba; Switch ] ~options:supplies_options ()

let max_candies = 99

let team_training_options : Run_options.declared list =
  [
    {
      key = "candies";
      value = Int_range (1, max_candies);
      presence = Default "98";
      doc = "how many Rare Candies to duplicate into the bag";
    };
  ]

let team_training =
  program ~id:"frlg.team_training" ~name:"Team Training" ~category:Farming
    ~description:"Copies Rare Candies with the Mail Glitch to level the team."
    ~dir:"team_training" ~backends:[ Mgba; Switch ]
    ~options:team_training_options ()

let catcher_prep =
  program ~id:"frlg.catcher_prep" ~name:"Catcher Prep" ~category:Farming
    ~description:
      "Catches and levels a Sleep and False Swipe catching pair for wild hunts."
    ~dir:"catcher_prep" ~backends:[ Mgba; Switch ] ()

(* 16-bit trainer and secret IDs (0..65535). *)
let max_trainer_id = 0xffff

let trainer_id_options : Run_options.declared list =
  [
    {
      key = "tid";
      value = Int_range (0, max_trainer_id);
      presence = Optional;
      doc =
        "your trainer ID (overrides GAMEPILOT_FRLG_TID and trainer_ids.json)";
    };
    {
      key = "sid";
      value = Int_range (0, max_trainer_id);
      presence = Optional;
      doc = "your secret ID (overrides GAMEPILOT_FRLG_SID and trainer_ids.json)";
    };
  ]

let dex_collection_options : Run_options.declared list =
  ([
     {
       key = "ball";
       value = One_of [ "poke-ball"; "great-ball"; "ultra-ball"; "luxury-ball" ];
       presence = Optional;
       doc = "the ball to throw (overrides each catch plan's default)";
     };
     {
       key = "balls";
       value = Int_range (1, bag_most);
       presence = Optional;
       doc = "max balls to throw per catch attempt (overrides plan default)";
     };
     {
       key = "target";
       value =
         One_of
           [
             "everything";
             "missing-on-dex";
             "version-exclusive";
             "version-exclusive-uncaught";
             "specific-list";
           ];
       presence = Default "everything";
       doc =
         "which species to catch (everything and missing-on-dex skip species \
          recorded in local dex_progress.json)";
     };
     {
       key = "species";
       value = Text;
       presence = Optional;
       doc =
         "comma-separated species slugs for target=specific-list (e.g. \
          ekans,voltorb)";
     };
   ]
    : Run_options.declared list)
  @ trainer_id_options

let dex_collection =
  {
    id = "frlg.dex_collection";
    game;
    name = "Dex Collection";
    category = Dex_collection;
    description =
      "Catches Pokemon the Pokedex lacks, toward the National Pokedex.";
    doc = "docs/guide/frlg.dex_collection.md";
    checkpoints = Some "src/games/pokemon/frlg/programs/dex_collection/plans";
    backends = [ Mgba ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
    options = dex_collection_options;
  }

let wild_rng =
  {
    id = "frlg.wild_rng";
    game;
    name = "Wild RNG";
    category = Shiny_hunting;
    description =
      "Catches a chosen shiny wild Pokemon by timing the game's random numbers.";
    doc = "docs/guide/frlg.wild_rng.md";
    checkpoints = Some "src/games/pokemon/frlg/programs/wild_rng/plans";
    backends = [ Mgba ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
    options = trainer_id_options;
  }

(* Grouped by category so [gamepilot programs] prints each heading once. *)
let all =
  [
    sevii_story;
    mail_glitch;
    ace_setup;
    ace;
    supplies;
    team_training;
    catcher_prep;
    dex_collection;
    wild_rng;
  ]
