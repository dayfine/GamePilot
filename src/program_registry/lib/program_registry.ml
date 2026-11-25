type backend = Mgba | Switch
type viewport = Nso_gba | Native
type game = { game_id : string; game_name : string }

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
}

let frlg = { game_id = "frlg"; game_name = "Pokémon FireRed/LeafGreen" }

let mail_glitch =
  {
    id = "frlg.mail_glitch";
    game = frlg;
    name = "Mail Glitch";
    group = [ "FRLG"; "Glitches" ];
    description =
      "Sets up the Mail Glitch, performs it against Lea & Jed on Route 16 and \
       uses it to duplicate an item.";
    doc = "docs/programs/frlg-mail-glitch.md";
    checkpoints = Some "src/games/frlg/programs/mail_glitch/plans";
    backends = [ Mgba; Switch ];
    viewport = Nso_gba;
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
  }

let team_training =
  {
    id = "frlg.team_training";
    game = frlg;
    name = "Team Training";
    group = [ "FRLG"; "Training" ];
    description =
      "Farms Rare Candies with the Mail Glitch's item duplication and levels \
       the team with them.";
    doc = "docs/programs/frlg-team-training.md";
    checkpoints = Some "src/games/frlg/programs/team_training/plans";
    backends = [ Mgba; Switch ];
    viewport = Nso_gba;
  }

let supplies =
  {
    id = "frlg.supplies";
    game = frlg;
    name = "Supplies";
    group = [ "FRLG"; "Training" ];
    description =
      "Stocks what the duplication programs use: Retro Mail and Super Repels.";
    doc = "docs/programs/frlg-supplies.md";
    checkpoints = Some "src/games/frlg/programs/supplies/plans";
    backends = [ Mgba; Switch ];
    viewport = Nso_gba;
  }

let sevii_story =
  {
    id = "frlg.sevii_story";
    game = frlg;
    name = "Sevii Story";
    group = [ "FRLG"; "Story" ];
    description =
      "Plays the Sevii Islands story after the Hall of Fame, starting with \
       Bill's trip to One Island.";
    doc = "docs/programs/frlg-sevii-story.md";
    checkpoints = Some "src/games/frlg/programs/sevii_story/plans";
    backends = [ Mgba ];
    viewport = Nso_gba;
  }

let dex_collection =
  {
    id = "frlg.dex_collection";
    game = frlg;
    name = "Dex Collection";
    group = [ "FRLG"; "Pokedex" ];
    description =
      "Catches wild Pokemon the Pokedex has not caught yet, toward the 60 the \
       National Pokedex needs.";
    doc = "docs/programs/frlg-dex-collection.md";
    checkpoints = Some "src/games/frlg/programs/dex_collection/plans";
    backends = [ Mgba ];
    viewport = Nso_gba;
  }

let all =
  [
    start_menu_poc;
    mail_glitch;
    supplies;
    team_training;
    sevii_story;
    dex_collection;
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
