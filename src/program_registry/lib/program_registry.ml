type backend = Mgba | Switch
type viewport = Nso_gba | Native
type rules = Pokemon_grid | Plza_story | Plza_home | Plza_gifts

type switch_home = {
  title : string;
  home_tile : Switch_home.Home_screen.tile_color;
  lab_panel : string;
}

type game = {
  game_id : string;
  game_name : string;
  delete_save_icons : (string * string) list;
  switch_home : switch_home option;
}

type t = {
  id : string;
  game : game;
  name : string;
  group : string list;
  description : string;
  doc : string;
  checkpoints : string option;
  backends : backend list;
  viewport : viewport;
  rules : rules;
  options : Run_options.declared list;
}

(* FireRed's tile on HOME: its orange background and Charizard, 0.41 of the
   art; the other tiles on console B 0.05 at most (2026-11-24). RGB, each
   bound 0 to 255. *)
let fire_red_tile : Switch_home.Home_screen.tile_color =
  let red_from = 200 and green_from = 40 in
  let full = 255 and green_to = 170 and blue_to = 100 in
  { min = (red_from, green_from, 0); max = (full, green_to, blue_to) }

(* Each icon is 82x82 frame pixels of the 90 px icon at (90, 30) on its
   "Delete Save Data for <user>" page, 4 px in. No FireRed page was captured:
   firered's is the game list's 135 px icon (game-list-za-first.png, at (157,
   397)) scaled to 90 px (Lanczos), then cut the same way; Z-A's made so
   scores 0.0054 on its page against the reader's 0.02. *)
let frlg =
  {
    game_id = "frlg";
    game_name = "Pokémon FireRed/LeafGreen";
    delete_save_icons =
      [
        ("firered", "src/games/pokemon/frlg/assets/delete-save-icon-firered.png");
      ];
    switch_home =
      Some
        {
          title = "FireRed";
          home_tile = fire_red_tile;
          lab_panel = "PokemonFRLG:AutoStory";
        };
  }

(* plza's icon is cut from console B's capture of that page
   (core/switch_home/test/images/delete-save/za-page-delete-save-data-for-user.png). *)
let plza =
  {
    game_id = "plza";
    game_name = "Pokémon Legends: Z-A";
    delete_save_icons =
      [ ("plza", "src/games/pokemon/plza/assets/delete-save-icon.png") ];
    switch_home = None;
  }

let bdsp =
  {
    game_id = "bdsp";
    game_name = "Pokémon Brilliant Diamond / Shining Pearl";
    delete_save_icons = [];
    switch_home = None;
  }

let games = [ plza; frlg; bdsp ]
let with_home (g : game) = Option.map (fun h -> (g, h)) g.switch_home

let home_ids () =
  String.concat ", "
    (List.map
       (fun ((g : game), _) -> g.game_id)
       (List.filter_map with_home games))

let by_id id =
  match List.find_opt (fun g -> g.game_id = id) games with
  | None ->
      Error ("no game " ^ id ^ "; games with Switch HOME data: " ^ home_ids ())
  | Some g ->
      Option.to_result
        ~none:(id ^ " has no Switch HOME data; games with it: " ^ home_ids ())
        (with_home g)

let only_one () =
  match List.filter_map with_home games with
  | [ one ] -> Ok one
  | _ ->
      Error ("set GAMEPILOT_LAB_GAME to the lab console's game: " ^ home_ids ())

let lab_game = function Some id -> by_id id | None -> only_one ()

let lab_game_of_env () =
  lab_game
    (match Sys.getenv_opt "GAMEPILOT_LAB_GAME" with
    | Some "" | None -> None
    | id -> id)

let frlg_mail_glitch =
  {
    id = "frlg.mail_glitch";
    game = frlg;
    name = "Mail Glitch";
    group = [ "FRLG"; "Glitches" ];
    description =
      "Turns on the Mail Glitch against Lea & Jed on Route 16 and copies one \
       item with it.";
    doc = "docs/guide/frlg.mail_glitch.md";
    checkpoints = Some "src/games/pokemon/frlg/programs/mail_glitch/plans";
    backends = [ Mgba; Switch ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
    options = [];
  }

let frlg_start_menu_poc =
  {
    id = "frlg.start_menu_poc";
    game = frlg;
    name = "Start Menu PoC";
    group = [ "FRLG"; "Development" ];
    description =
      "Opens and closes the Start menu: the first program through the daemon.";
    doc = "docs/poc-start-menu.md";
    checkpoints = None;
    backends = [ Mgba ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
    options = [];
  }

let frlg_team_training =
  {
    id = "frlg.team_training";
    game = frlg;
    name = "Team Training";
    group = [ "FRLG"; "Training" ];
    description = "Copies Rare Candies with the Mail Glitch to level the team.";
    doc = "docs/guide/frlg.team_training.md";
    checkpoints = Some "src/games/pokemon/frlg/programs/team_training/plans";
    backends = [ Mgba; Switch ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
    options = [];
  }

let frlg_supplies =
  {
    id = "frlg.supplies";
    game = frlg;
    name = "Supplies";
    group = [ "FRLG"; "Training" ];
    description =
      "Stocks what the duplication programs use: Retro Mail and Super Repels.";
    doc = "docs/guide/frlg.supplies.md";
    checkpoints = Some "src/games/pokemon/frlg/programs/supplies/plans";
    backends = [ Mgba; Switch ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
    options = [];
  }

let frlg_sevii_story =
  {
    id = "frlg.sevii_story";
    game = frlg;
    name = "Sevii Story";
    group = [ "FRLG"; "Story" ];
    description = "Plays the Sevii Islands story after the Cinnabar Gym.";
    doc = "docs/guide/frlg.sevii_story.md";
    checkpoints = Some "src/games/pokemon/frlg/programs/sevii_story/plans";
    backends = [ Mgba ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
    options = [];
  }

let frlg_ace_setup =
  {
    id = "frlg.ace_setup";
    game = frlg;
    name = "ACE Setup";
    group = [ "FRLG"; "Glitches" ];
    description =
      "Sets up arbitrary code execution: the ? Mail puts species 0x0351 in Box \
       3 slot 1.";
    doc = "docs/guide/frlg.ace_setup.md";
    checkpoints = Some "src/games/pokemon/frlg/programs/ace_setup/plans";
    backends = [ Mgba ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
    options = [];
  }

(* The most of one item the bag holds. *)
let bag_most = 999

let frlg_ace =
  {
    id = "frlg.ace";
    game = frlg;
    name = "ACE";
    group = [ "FRLG"; "Glitches" ];
    description =
      "Runs code typed as PC box names through species 0x0351: 999 of an item \
       in the PC, some of them to the bag.";
    doc = "docs/guide/frlg.ace.md";
    checkpoints = Some "src/games/pokemon/frlg/programs/ace/plans";
    backends = [ Mgba ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
    options =
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
      ];
  }

let frlg_dex_collection =
  {
    id = "frlg.dex_collection";
    game = frlg;
    name = "Dex Collection";
    group = [ "FRLG"; "Pokedex" ];
    description =
      "Catches Pokemon the Pokedex lacks, toward the National Pokedex.";
    doc = "docs/guide/frlg.dex_collection.md";
    checkpoints = Some "src/games/pokemon/frlg/programs/dex_collection/plans";
    backends = [ Mgba ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
    options = [];
  }

let frlg_wild_rng =
  {
    id = "frlg.wild_rng";
    game = frlg;
    name = "Wild RNG";
    group = [ "FRLG"; "RNG" ];
    description =
      "Catches a chosen shiny wild Pokemon by timing the game's random numbers.";
    doc = "docs/guide/frlg.wild_rng.md";
    checkpoints = Some "src/games/pokemon/frlg/programs/wild_rng/plans";
    backends = [ Mgba ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
    options = [];
  }

let plza_autostory =
  {
    id = "plza.autostory";
    game = plza;
    name = "AutoStory";
    group = [ "PLZA"; "Story" ];
    description = "Plays the story from a new game, checkpoint by checkpoint.";
    doc = "docs/guide/plza.autostory.md";
    checkpoints = Some "src/games/pokemon/plza/programs/autostory/plans";
    backends = [ Switch ];
    viewport = Native;
    rules = Plza_story;
    options = Plza_story.New_game_choices.decls;
  }

let plza_claim_gifts =
  {
    id = "plza.claim-gifts";
    game = plza;
    name = "Claim Gifts";
    group = [ "PLZA"; "Gifts" ];
    description =
      "Claims the Mystery Gifts of its catalog that have not expired, puts \
       their Pokémon in the Boxes and saves.";
    doc = "docs/guide/plza.claim-gifts.md";
    checkpoints = Some "src/games/pokemon/plza/programs/claim_gifts/plans";
    backends = [ Switch ];
    viewport = Native;
    rules = Plza_gifts;
    options =
      [
        {
          key = "language";
          value = One_of Plza_story.New_game_choices.tags;
          presence = Default "en";
          doc =
            "the game's language, by its language list's tag, in which the \
             Internet gifts' names are found in their list";
        };
      ];
  }

let plza_bank_home =
  {
    id = "plza.bank-home";
    game = plza;
    name = "Bank in HOME";
    group = [ "PLZA"; "Pokémon HOME" ];
    description =
      "Moves the claimed gifts from the game's box into their Pokémon HOME \
       boxes and saves HOME.";
    doc = "docs/guide/plza.bank-home.md";
    checkpoints = Some "src/games/pokemon/plza/programs/bank_home/plans";
    backends = [ Switch ];
    viewport = Native;
    rules = Plza_home;
    options = [];
  }

let max_underground_cycles = 999
let max_underground_slates = 99

let bdsp_underground_poc =
  {
    id = "bdsp.underground_poc";
    game = bdsp;
    name = "Underground PoC";
    group = [ "BDSP"; "Development" ];
    description =
      "Iterative Switch bring-up program for Grand Underground shard farming.";
    doc = "docs/guide/bdsp.underground_poc.md";
    checkpoints = None;
    backends = [ Switch ];
    viewport = Native;
    rules = Pokemon_grid;
    options =
      [
        {
          key = "mode";
          value =
            Run_options.One_of
              [
                "farm";
                "check-bag";
                "check-map";
                "step-refresh";
                "step-read-map";
                "step-route-one";
                "step-dig-one";
              ];
          presence = Run_options.Default "farm";
          doc =
            "farm: full Grand Underground shard loop; check-bag: inspect \
             Treasures pocket; check-map: capture full-sized map (Y -> A); \
             step-refresh / step-read-map / step-route-one / step-dig-one: \
             isolated single-step verification modes.";
        };
        {
          key = "door";
          value = Run_options.One_of [ "south"; "north" ];
          presence = Run_options.Default "south";
          doc = "Starting Hideaway doorway for step-route-one (south or north).";
        };
        {
          key = "cycles";
          value = Run_options.Int_range (1, max_underground_cycles);
          presence = Run_options.Default "15";
          doc = "Number of Hideaway doorway-refresh cycles to run in farm mode.";
        };
        {
          key = "slates";
          value = Run_options.Int_range (1, max_underground_slates);
          presence = Run_options.Default "14";
          doc =
            "Ramanas Park slate budget (1 Shard L or 3 Shard S per slate); \
             stops once reached.";
        };
      ];
  }

let all =
  [
    frlg_start_menu_poc;
    frlg_mail_glitch;
    frlg_supplies;
    frlg_team_training;
    frlg_sevii_story;
    frlg_dex_collection;
    frlg_ace_setup;
    frlg_ace;
    frlg_wild_rng;
    plza_autostory;
    plza_claim_gifts;
    plza_bank_home;
    bdsp_underground_poc;
  ]

let short_id p =
  let prefix = p.game.game_id ^ "." in
  let n = String.length prefix in
  if String.starts_with ~prefix p.id then
    String.sub p.id n (String.length p.id - n)
  else p.id

let find id =
  match List.find_opt (fun p -> p.id = id) all with
  | Some p -> Some p
  | None -> (
      match List.filter (fun p -> short_id p = id) all with
      | [ p ] -> Some p
      | _ -> None)

let segments path =
  String.split_on_char '/' path |> List.filter (fun s -> s <> "" && s <> ".")

let rec ends_with ~suffix list =
  list = suffix
  || match list with [] -> false | _ :: rest -> ends_with ~suffix rest

let of_plan_dir dir =
  let dir = segments dir in
  List.find_opt
    (fun p ->
      match p.checkpoints with
      | Some c -> ends_with ~suffix:(segments c) dir
      | None -> false)
    all

let locate = Repo_io.Repo_files.locate

let of_checkpoint id =
  let has_plan p =
    match Option.bind p.checkpoints locate with
    | Some dir -> Sys.file_exists (Filename.concat dir (id ^ ".plan.json"))
    | None -> false
  in
  List.find_opt has_plan all

let backend_name = function Mgba -> "mgba" | Switch -> "switch"
let viewport_name = function Nso_gba -> "nso-gba" | Native -> "native"

let viewport_mismatch p given =
  Printf.sprintf
    "--viewport %s: %s's game picture is %s (program_registry); drop \
     --viewport, or fix the program's descriptor"
    given p.id (viewport_name p.viewport)

let check_viewport program given =
  match (program, given) with
  | None, given -> Ok given
  | Some p, None -> Ok (Some (viewport_name p.viewport))
  | Some p, Some v when v = viewport_name p.viewport -> Ok (Some v)
  | Some p, Some v -> Error (viewport_mismatch p v)

let check_options program given =
  let decls = Option.fold ~none:[] ~some:(fun p -> p.options) program in
  Run_options.check decls given

let run_fields p =
  [
    ("game", p.game.game_id);
    ("game_name", p.game.game_name);
    ("program", p.id);
    ("program_name", p.name);
    ("group", String.concat " / " p.group);
  ]
