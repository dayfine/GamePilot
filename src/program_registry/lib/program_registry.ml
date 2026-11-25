type backend = Mgba | Switch
type viewport = Nso_gba | Native
type rules = Pokemon_grid

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
      [ ("firered", "src/games/frlg/assets/delete-save-icon-firered.png") ];
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

let games = [ plza; frlg ]
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

let mail_glitch =
  {
    id = "frlg.mail_glitch";
    game = frlg;
    name = "Mail Glitch";
    group = [ "FRLG"; "Glitches" ];
    description =
      "Turns on the Mail Glitch against Lea & Jed on Route 16 and copies one \
       item with it.";
    doc = "docs/guide/frlg.mail_glitch.md";
    checkpoints = Some "src/games/frlg/programs/mail_glitch/plans";
    backends = [ Mgba; Switch ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
  }

let start_menu_poc =
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
  }

let team_training =
  {
    id = "frlg.team_training";
    game = frlg;
    name = "Team Training";
    group = [ "FRLG"; "Training" ];
    description = "Copies Rare Candies with the Mail Glitch to level the team.";
    doc = "docs/guide/frlg.team_training.md";
    checkpoints = Some "src/games/frlg/programs/team_training/plans";
    backends = [ Mgba; Switch ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
  }

let supplies =
  {
    id = "frlg.supplies";
    game = frlg;
    name = "Supplies";
    group = [ "FRLG"; "Training" ];
    description =
      "Stocks what the duplication programs use: Retro Mail and Super Repels.";
    doc = "docs/guide/frlg.supplies.md";
    checkpoints = Some "src/games/frlg/programs/supplies/plans";
    backends = [ Mgba; Switch ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
  }

let sevii_story =
  {
    id = "frlg.sevii_story";
    game = frlg;
    name = "Sevii Story";
    group = [ "FRLG"; "Story" ];
    description = "Plays the Sevii Islands story after the Cinnabar Gym.";
    doc = "docs/guide/frlg.sevii_story.md";
    checkpoints = Some "src/games/frlg/programs/sevii_story/plans";
    backends = [ Mgba ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
  }

let ace_setup =
  {
    id = "frlg.ace_setup";
    game = frlg;
    name = "ACE Setup";
    group = [ "FRLG"; "Glitches" ];
    description =
      "Sets up arbitrary code execution: the ? Mail puts species 0x0351 in Box \
       3 slot 1.";
    doc = "docs/guide/frlg.ace_setup.md";
    checkpoints = Some "src/games/frlg/programs/ace_setup/plans";
    backends = [ Mgba ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
  }

let dex_collection =
  {
    id = "frlg.dex_collection";
    game = frlg;
    name = "Dex Collection";
    group = [ "FRLG"; "Pokedex" ];
    description =
      "Catches Pokemon the Pokedex lacks, toward the National Pokedex.";
    doc = "docs/guide/frlg.dex_collection.md";
    checkpoints = Some "src/games/frlg/programs/dex_collection/plans";
    backends = [ Mgba ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
  }

let wild_rng =
  {
    id = "frlg.wild_rng";
    game = frlg;
    name = "Wild RNG";
    group = [ "FRLG"; "RNG" ];
    description =
      "Catches a chosen shiny wild Pokemon by timing the game's random numbers.";
    doc = "docs/guide/frlg.wild_rng.md";
    checkpoints = Some "src/games/frlg/programs/wild_rng/plans";
    backends = [ Mgba ];
    viewport = Nso_gba;
    rules = Pokemon_grid;
  }

let all =
  [
    start_menu_poc;
    mail_glitch;
    supplies;
    team_training;
    sevii_story;
    dex_collection;
    ace_setup;
    wild_rng;
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

let run_fields p =
  [
    ("game", p.game.game_id);
    ("game_name", p.game.game_name);
    ("program", p.id);
    ("program_name", p.name);
    ("group", String.concat " / " p.group);
  ]
