(* What a program's chain needs of the save, as gamepilot programs prints it:
   the free party slots (Frlg_checkpoints.Party_room, as the pre-flight's room
   row) and the field moves its plans use (Frlg_checkpoints.Plan_needs: Fly's
   user, Cut's user). *)

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
  let module N = Frlg_checkpoints.Need in
  let field_move = function
    | N.Member { species; for_ }
      when List.mem for_ Frlg_checkpoints.Party_room.field_moves ->
        Some (Printf.sprintf "%s (%s)" for_ species)
    | N.Knows_move { move; _ } -> Some (move ^ " (a member that knows it)")
    | _ -> None
  in
  List.concat_map
    (fun plan ->
      List.filter_map field_move
        (Frlg_checkpoints.Plan_needs.needs stocks ~before:None plan))
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
