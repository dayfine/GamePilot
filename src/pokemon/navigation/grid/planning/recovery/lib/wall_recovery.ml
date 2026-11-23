type ('hypothesis, 'hold) step = { positions : 'hypothesis list; hold : 'hold }
type ('position, 'hold) anchor = { holds : 'hold list; at : 'position }

module type Movement = sig
  type context
  type hypothesis
  type position
  type hold

  val position : hypothesis -> position
  val equal_hypothesis : hypothesis -> hypothesis -> bool
  val equal_position : position -> position -> bool

  val hold :
    context -> hypothesis list -> Direction.t -> (hypothesis, hold) step option

  val tiles : hold -> int
end

module Make (M : Movement) = struct
  let default_max_holds = 3
  let at_first first h = M.equal_position (M.position h) (M.position first)

  (* The one position every candidate is at, if there is one. *)
  let converged = function
    | [] -> None
    | first :: rest when List.for_all (at_first first) rest ->
        Some (M.position first)
    | _ -> None

  (* A hold worth trying: it moves the candidates somewhere new. *)
  let moves from (step : _ step) =
    step.positions <> []
    && (not (List.equal M.equal_hypothesis step.positions from))
    && M.tiles step.hold <> 0

  (* Anchors reached with exactly [depth] more holds after [held] (newest
     first), in direction order. *)
  let rec search context positions depth held =
    List.concat_map (anchors_after context positions depth held) Direction.all

  and anchors_after context positions depth held direction =
    match M.hold context positions direction with
    | Some step when moves positions step -> after_hold context depth held step
    | _ -> []

  and after_hold context depth held step =
    let held = step.hold :: held in
    match converged step.positions with
    | Some at when depth = 1 -> [ { holds = List.rev held; at } ]
    | Some _ -> []
    | None when depth > 1 -> search context step.positions (depth - 1) held
    | None -> []

  let total_tiles anchor =
    List.fold_left (fun sum hold -> sum + M.tiles hold) 0 anchor.holds

  let by_tiles a b = compare (total_tiles a) (total_tiles b)

  (* The anchors of the fewest holds from [depth] up to [max_holds]. *)
  let rec deepen context positions ~max_holds depth =
    if depth > max_holds then []
    else
      match search context positions depth [] with
      | [] -> deepen context positions ~max_holds (depth + 1)
      | found -> List.stable_sort by_tiles found

  let find_anchors ?(max_holds = default_max_holds) context positions =
    match (positions, converged positions) with
    | [], _ -> []
    | _, Some at -> [ { holds = []; at } ]
    | _, None -> deepen context positions ~max_holds 1
end
