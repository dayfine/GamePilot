type backend = Mgba | Switch
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
  }

let all = [ start_menu_poc; mail_glitch; team_training ]

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

let locate = Frlg_repo_files.Repo_files.locate

let of_checkpoint id =
  let has_plan p =
    match Option.bind p.checkpoints locate with
    | Some dir -> Sys.file_exists (Filename.concat dir (id ^ ".plan.json"))
    | None -> false
  in
  List.find_opt has_plan all

let backend_name = function Mgba -> "mgba" | Switch -> "switch"

let run_fields p =
  [
    ("game", p.game.game_id);
    ("game_name", p.game.game_name);
    ("program", p.id);
    ("program_name", p.name);
    ("group", String.concat " / " p.group);
  ]
