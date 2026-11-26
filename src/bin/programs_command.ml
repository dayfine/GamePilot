(* gamepilot programs

   The program registry (Program_registry) by game and group, as PA/CC's
   program list shows it: each program's id, name, backends, its Switch game
   picture (the daemon's --viewport), description and
   page, the keys its --options take, and for a program with checkpoints its checkpoint ids and what its
   chain needs of the save, as its rules say it (Checkpoint_families: free
   party slots, field moves).

   Also resolves a program id for gamepilot run to its checkpoints' plan
   folder. *)

module R = Program_registry

let usage = "  gamepilot programs\n"
let ( let* ) = Result.bind

let plan_lines ~needs path dir =
  let ids =
    Result.value (Engine_series.Plan_folder.checkpoint_ids dir) ~default:[]
  in
  let needs =
    match needs dir with Ok n -> n | Error e -> "not derived: " ^ e
  in
  [
    "checkpoints: " ^ String.concat ", " ids ^ " (" ^ path ^ ")";
    "needs: " ^ needs;
  ]

let checkpoint_lines (p : R.t) =
  match Option.map (fun path -> (path, R.locate path)) p.checkpoints with
  | None -> [ "checkpoints: none" ]
  | Some (path, None) -> [ "checkpoints: " ^ path ^ " (not found from here)" ]
  | Some (path, Some dir) ->
      let family = Checkpoint_families.of_program (Some p) in
      plan_lines ~needs:family.chain_needs path dir

(* Each key the program takes in --options, with its values. *)
let option_lines (p : R.t) =
  List.map (fun d -> "--options " ^ Run_options.describe d) p.options

let show (p : R.t) =
  Printf.printf "    %s  %s  [%s]  viewport %s\n" p.id p.name
    (String.concat ", " (List.map R.backend_name p.backends))
    (R.viewport_name p.viewport);
  List.iter
    (fun line -> print_endline ("      " ^ line))
    ((p.description :: ("doc: " ^ p.doc) :: option_lines p) @ checkpoint_lines p)

(* Each game and each category once, above its programs. *)
let show_under (game, category) (p : R.t) =
  if p.game.game_id <> game then
    Printf.printf "%s (%s)\n" p.game.game_name p.game.game_id;
  if p.game.game_id <> game || category <> Some p.category then
    print_endline ("  " ^ R.category_name p.category);
  show p;
  (p.game.game_id, Some p.category)

let main = function
  | [] ->
      ignore (List.fold_left show_under ("", None) R.all);
      Ok 0
  | a :: _ -> Error ("unknown argument " ^ a)

let unknown id = Error ("no program " ^ id ^ ": gamepilot programs lists them")

(* The plan folder of the program [id] names. *)
let plan_dir id =
  match R.find id with
  | None -> unknown id
  | Some ({ checkpoints = None; _ } as p) ->
      Error (p.id ^ " has no checkpoint plans")
  | Some { checkpoints = Some path; _ } -> (
      match R.locate path with
      | Some dir -> Ok dir
      | None -> Error (path ^ " not found from here: run in the repo"))
