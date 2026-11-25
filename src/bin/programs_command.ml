(* gamepilot programs

   The program registry (Program_registry) by game and group, as PA/CC's
   program list shows it: each program's id, name, backends, its Switch game
   picture (the daemon's --viewport), description and
   page, and for a program with checkpoints its checkpoint ids and what its
   chain needs of the save, as its rules say it (Checkpoint_families: free
   party slots, field moves).

   Also the program gamepilot run or replay names by its id: a one-shot
   program, or a chain of checkpoints and its plan folder. *)

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
  | None -> [ "one-shot: gamepilot run " ^ p.id ]
  | Some (path, None) -> [ "checkpoints: " ^ path ^ " (not found from here)" ]
  | Some (path, Some dir) ->
      plan_lines ~needs:(Checkpoint_families.of_program (Some p)).chain_needs
        path dir

let show (p : R.t) =
  Printf.printf "    %s  %s  [%s]  viewport %s\n" p.id p.name
    (String.concat ", " (List.map R.backend_name p.backends))
    (R.viewport_name p.viewport);
  List.iter
    (fun line -> print_endline ("      " ^ line))
    (p.description :: ("doc: " ^ p.doc) :: checkpoint_lines p)

(* Each game and each group once, above its programs. *)
let show_under (game, group) (p : R.t) =
  if p.game.game_id <> game then
    Printf.printf "%s (%s)\n" p.game.game_name p.game.game_id;
  if p.game.game_id <> game || p.group <> group then
    print_endline ("  " ^ String.concat " / " p.group);
  show p;
  (p.game.game_id, p.group)

let main = function
  | [] ->
      ignore (List.fold_left show_under ("", []) R.all);
      Ok 0
  | a :: _ -> Error ("unknown argument " ^ a)

let unknown id = Error ("no program " ^ id ^ ": gamepilot programs lists them")

type runnable = One_shot of R.t | Chain of R.t * string

(* The program [id] names: one-shot, or its checkpoints and their plan
   folder. *)
let runnable id =
  match R.find id with
  | None -> unknown id
  | Some ({ checkpoints = None; _ } as p) -> Ok (One_shot p)
  | Some ({ checkpoints = Some path; _ } as p) -> (
      match R.locate path with
      | Some dir -> Ok (Chain (p, dir))
      | None -> Error (path ^ " not found from here: run in the repo"))

(* A one-shot program by its id (gamepilot replay). *)
let one_shot id =
  match R.find id with
  | Some ({ checkpoints = None; _ } as p) -> Ok p
  | Some p -> Error (p.id ^ " runs by checkpoints, live: gamepilot run " ^ p.id)
  | None -> unknown id
