(* gamepilot programs

   The program registry (Program_registry) by game and group, as PA/CC's
   program list shows it: each program's id, name, backends, its Switch game
   picture (the daemon's --viewport), description and
   page, and for a program with checkpoints its checkpoint ids and what its
   chain needs of the save: the free party slots (Frlg_checkpoints.Party_room, as
   the pre-flight's room row) and the field moves its plans use
   (Frlg_checkpoints.Plan_needs: Fly's user, Cut's user).

   Also the program a command names: --program ID in place of a plan folder
   (gamepilot checkpoints), or a one-shot program's id (gamepilot run). *)

module R = Program_registry

let usage = "  gamepilot programs\n"
let ( let* ) = Result.bind

let load_plans dir =
  let* ids = Plan_dir.checkpoint_ids dir in
  List.fold_left
    (fun acc id ->
      let* acc = acc in
      let* plan = Plan_dir.load_plan ~plan_dir:dir id in
      Ok (plan :: acc))
    (Ok []) ids
  |> Result.map List.rev

(* "fly (pidgey)" for each field move a plan uses, without repeats. *)
let field_moves stocks plans =
  let module N = Frlg_checkpoints.Plan_needs in
  let field_move = function
    | N.Member { species; for_ }
      when List.mem for_ Frlg_checkpoints.Party_room.field_moves ->
        Some (Printf.sprintf "%s (%s)" for_ species)
    | N.Knows_move { move; _ } -> Some (move ^ " (a member that knows it)")
    | _ -> None
  in
  List.concat_map
    (fun plan -> List.filter_map field_move (N.needs stocks ~before:None plan))
    plans
  |> List.sort_uniq compare

let needs dir =
  let* plans = load_plans dir in
  let* stocks = Frlg_actions.Mart_plan.load () in
  match
    ( Frlg_checkpoints.Party_room.(free_needed (chain_need plans)),
      field_moves stocks plans )
  with
  | free, moves ->
      let moves = if moves = [] then "none" else String.concat ", " moves in
      Ok (Printf.sprintf "%d free party slot(s); field moves: %s" free moves)
  | exception Json_field.Invalid e -> Error e

let plan_lines path dir =
  let ids = Result.value (Plan_dir.checkpoint_ids dir) ~default:[] in
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
  | Some (path, Some dir) -> plan_lines path dir

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

(* The plan folder of --program ID, wherever it is in [args], and the other
   args; else the first arg is the plan folder. *)
let rec plan_dir_of_args = function
  | "--program" :: id :: rest -> (
      match R.find id with
      | None -> unknown id
      | Some { checkpoints = None; _ } ->
          Error (id ^ " has no checkpoints: gamepilot run " ^ id)
      | Some { checkpoints = Some path; _ } -> (
          match R.locate path with
          | Some dir -> Ok (dir, rest)
          | None -> Error (path ^ " not found from here: run in the repo")))
  | a :: rest when List.mem "--program" rest ->
      Result.map (fun (dir, rest) -> (dir, a :: rest)) (plan_dir_of_args rest)
  | dir :: rest -> Ok (dir, rest)
  | [] -> Error "a plan folder or --program ID is required"

(* A one-shot program by its id. *)
let one_shot id =
  match R.find id with
  | Some ({ checkpoints = None; _ } as p) -> Ok p
  | Some p ->
      Error
        (p.id ^ " runs by checkpoints: gamepilot checkpoints --program " ^ p.id)
  | None -> unknown id
