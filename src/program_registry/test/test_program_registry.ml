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

let plan_error file =
  match Story.Plan_decode.load file with
  | Error e -> Some (file ^ ": " ^ e)
  | Ok plan -> (
      match Frlg_story.Checkpoint_run.check_plan plan with
      | Ok () -> None
      | Error e -> Some (file ^ ": " ^ e))

(* Every plan of every program's folder that does not decode or check. *)
let bad_plans () =
  List.concat_map
    (fun (p : R.t) ->
      match Option.bind p.checkpoints R.locate with
      | None -> []
      | Some dir -> List.filter_map plan_error (plans_in dir))
    R.all
  |> String.concat "\n"

let plan_count () =
  match R.locate "src/games/frlg/programs/mail_glitch/plans" with
  | Some dir -> string_of_bool (plans_in dir <> [])
  | None -> "no folder"

let id_of = function Some (p : R.t) -> p.id | None -> "none"

let () =
  Table_test.run "program_registry"
    [
      case "ids are unique" duplicates "";
      case "every doc exists" (missing (fun p -> Some p.doc)) "";
      case "every checkpoints folder exists"
        (missing (fun p -> p.checkpoints))
        "";
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
          id_of (R.of_plan_dir "src/games/frlg/programs/mail_glitch/plans/"))
        "frlg.mail_glitch";
      case "plan dir: absolute, ./ inside"
        (fun () ->
          id_of
            (R.of_plan_dir
               "/x/GamePilot/./src/games/frlg/programs/mail_glitch/plans"))
        "frlg.mail_glitch";
      case "plan dir: a scratch copy is no program"
        (fun () -> id_of (R.of_plan_dir "/tmp/mail_glitch/plans"))
        "none";
      case "checkpoint: mg-05a is the mail glitch's"
        (fun () -> id_of (R.of_checkpoint "mg-05a"))
        "frlg.mail_glitch";
      case "checkpoint: a scratch plan's id is no program's"
        (fun () -> id_of (R.of_checkpoint "pc-01"))
        "none";
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
