(* The registry's entries against the repo: unique ids, docs and checkpoint
   folders that exist, plans that decode; and the lookups the CLI and the
   backfill use. *)

module R = Program_registry

let case name input expectation = { Table_test.name; input; expectation }
let ids () = List.map (fun (p : R.t) -> p.id) R.all

let duplicates () =
  let sorted = List.sort compare (ids ()) in
  let rec go = function
    | a :: (b :: _ as rest) -> if a = b then a :: go rest else go rest
    | _ -> []
  in
  String.concat ", " (go sorted)

(* Each program's repo paths that do not exist. *)
let missing field () =
  List.filter_map
    (fun (p : R.t) ->
      match field p with
      | Some path when R.locate path = None -> Some (p.id ^ ": " ^ path)
      | _ -> None)
    R.all
  |> String.concat ", "

let plans_in dir =
  Sys.readdir dir |> Array.to_list
  |> List.filter (fun n -> Filename.check_suffix n ".plan.json")
  |> List.map (Filename.concat dir)

(* PLZA's plans are over its own rules: they decode with Plza_engine. *)
let plza_plan_error file =
  match Plza_engine.Plan_decode.load file with
  | Ok _ -> None
  | Error e -> Some (file ^ ": " ^ e)

let frlg_plan_error file =
  match Frlg_checkpoints.Plan_file.load file with
  | Error e -> Some (file ^ ": " ^ e)
  | Ok plan -> (
      match Frlg_checkpoints.Checkpoint_run.check_plan plan with
      | Ok () -> None
      | Error e -> Some (file ^ ": " ^ e))

(* Every plan of every program's folder that does not decode or check. *)
let bad_plans () =
  List.concat_map
    (fun (p : R.t) ->
      match Option.bind p.checkpoints R.locate with
      | None -> []
      | Some dir ->
          let plan_error =
            match p.rules with
            | Plza_story | Plza_home | Plza_gifts -> plza_plan_error
            | Pokemon_grid -> frlg_plan_error
          in
          List.filter_map plan_error (plans_in dir))
    R.all
  |> String.concat "\n"

let plan_count () =
  match R.locate "src/games/pokemon/frlg/programs/mail_glitch/plans" with
  | Some dir -> string_of_bool (plans_in dir <> [])
  | None -> "no folder"

(* A run's --viewport for [program] given [flag], as the CLI prints it. *)
let viewport_for program flag =
  match R.check_viewport (Option.bind program R.find) flag with
  | Ok (Some v) -> v
  | Ok None -> "default"
  | Error e -> "error: " ^ e

(* Every game's delete-save icons that are not found from here. *)
let missing_icons () =
  List.concat_map (fun (g : R.game) -> g.delete_save_icons) R.games
  |> List.filter_map (fun (key, path) ->
         if R.locate path = None then Some (key ^ ": " ^ path) else None)
  |> String.concat ", "

(* The lab game an id (or none) picks, or its error. *)
let lab_game_text id =
  match R.lab_game id with
  | Ok (g, home) -> g.game_id ^ " " ^ home.title ^ " " ^ home.lab_panel
  | Error e -> "error: " ^ e

(* Every program whose options declaration has an error of its own. *)
let bad_options () =
  List.filter_map
    (fun (p : R.t) ->
      match Run_options.check_declaration p.options with
      | Ok () -> None
      | Error e -> Some (p.id ^ ": " ^ e))
    R.all
  |> String.concat ", "

(* A run's --options for [program], as gamepilot run reads them. *)
let options_for program given =
  match R.check_options (Option.bind program R.find) given with
  | Ok t -> "ok " ^ Run_options.to_text t
  | Error e -> "error: " ^ e

let id_of = function Some (p : R.t) -> p.id | None -> "none"

(* frlg.ace's item choices against the vetted table's items
   (src/games/pokemon/frlg/assets/ace_presets.json): a preset added to one and not the
   other shows here. *)
let ace_items () =
  let declared =
    match R.find "frlg.ace" with
    | None -> "no frlg.ace"
    | Some p -> (
        match
          List.find_opt
            (fun (d : Run_options.declared) -> d.key = "item")
            p.options
        with
        | Some { value = One_of items; _ } -> String.concat ", " items
        | _ -> "no item choice")
  in
  match Frlg_actions.Ace_presets.load () with
  | Error e -> e
  | Ok t ->
      let table = String.concat ", " (Frlg_actions.Ace_presets.slugs t) in
      if declared = table then "same" else declared ^ " | " ^ table

let () =
  Table_test.run "program_registry"
    [
      case "ids are unique" duplicates "";
      case "every doc exists" (missing (fun p -> Some p.doc)) "";
      case "every checkpoints folder exists"
        (missing (fun p -> p.checkpoints))
        "";
      case "every delete-save icon exists" missing_icons "";
      case "lab game: none given, the one with Switch HOME data"
        (fun () -> lab_game_text None)
        "frlg FireRed PokemonFRLG:AutoStory";
      case "lab game: by id"
        (fun () -> lab_game_text (Some "frlg"))
        "frlg FireRed PokemonFRLG:AutoStory";
      case "lab game: a game with no Switch HOME data"
        (fun () -> lab_game_text (Some "plza"))
        "error: plza has no Switch HOME data; games with it: frlg";
      case "lab game: an unknown id"
        (fun () -> lab_game_text (Some "sv"))
        "error: no game sv; games with Switch HOME data: frlg";
      case "the mail glitch folder has plans" plan_count "true";
      case "every plan decodes and checks" bad_plans "";
      case "find by id"
        (fun () -> id_of (R.find "frlg.mail_glitch"))
        "frlg.mail_glitch";
      case "find by the part after the game"
        (fun () -> id_of (R.find "start_menu_poc"))
        "frlg.start_menu_poc";
      case "find: unknown" (fun () -> id_of (R.find "mail")) "none";
      case "plan dir: relative, trailing slash"
        (fun () ->
          id_of
            (R.of_plan_dir "src/games/pokemon/frlg/programs/mail_glitch/plans/"))
        "frlg.mail_glitch";
      case "plan dir: absolute, ./ inside"
        (fun () ->
          id_of
            (R.of_plan_dir
               "/x/GamePilot/./src/games/pokemon/frlg/programs/mail_glitch/plans"))
        "frlg.mail_glitch";
      case "plan dir: a scratch copy is no program"
        (fun () -> id_of (R.of_plan_dir "/tmp/mail_glitch/plans"))
        "none";
      case "checkpoint: 07-glitch-prep is the mail glitch's"
        (fun () -> id_of (R.of_checkpoint "07-glitch-prep"))
        "frlg.mail_glitch";
      case "checkpoint: a scratch plan's id is no program's"
        (fun () -> id_of (R.of_checkpoint "pc-01"))
        "none";
      case "every FRLG program shows the GBA app's picture"
        (fun () ->
          List.filter
            (fun (p : R.t) ->
              p.game.game_id = "frlg" && p.viewport <> R.Nso_gba)
            R.all
          |> List.map (fun (p : R.t) -> p.id)
          |> String.concat ", ")
        "";
      case "viewport: the program's, no flag"
        (fun () -> viewport_for (Some "frlg.mail_glitch") None)
        "nso-gba";
      case "viewport: a flag that agrees"
        (fun () -> viewport_for (Some "frlg.mail_glitch") (Some "nso-gba"))
        "nso-gba";
      case "viewport: a flag that disagrees is an error"
        (fun () -> viewport_for (Some "frlg.mail_glitch") (Some "native"))
        "error: --viewport native: frlg.mail_glitch's game picture is nso-gba \
         (program_registry); drop --viewport, or fix the program's descriptor";
      case "viewport: no program, the flag as given"
        (fun () -> viewport_for None (Some "0.1,0,0.8,1"))
        "0.1,0,0.8,1";
      case "viewport: no program, no flag"
        (fun () -> viewport_for None None)
        "default";
      case "every options declaration is sound" bad_options "";
      case "frlg.ace's items are the preset table's" ace_items "same";
      case "options: none given to a program that takes none"
        (fun () -> options_for (Some "frlg.mail_glitch") [])
        "ok ";
      case "options: refused by a program that takes none"
        (fun () -> options_for (Some "frlg.mail_glitch") [ ("item", "x") ])
        "error: --options item: this program takes no options";
      case "options: plza.autostory, none given: the plan's"
        (fun () -> options_for (Some "plza.autostory") [])
        "ok ";
      case "options: plza.autostory refuses Korean"
        (fun () -> options_for (Some "plza.autostory") [ ("language", "ko") ])
        "error: --options language=ko: language is en | es-ES | es-419 | fr | \
         de | it | ja | zh-Hant";
      case "options: refused for a plan folder no program registers"
        (fun () -> options_for None [ ("item", "x") ])
        "error: --options item: this program takes no options";
      case "run.json fields"
        (fun () ->
          Option.get (R.find "frlg.mail_glitch")
          |> R.run_fields
          |> List.map (fun (k, v) -> k ^ "=" ^ v)
          |> String.concat "; ")
        "game=frlg; game_name=Pokémon FireRed/LeafGreen; \
         program=frlg.mail_glitch; program_name=Mail Glitch; group=FRLG / \
         Glitches";
    ]
