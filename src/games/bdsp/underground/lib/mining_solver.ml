type action =
  | Strike of { tool : Mining_wall.tool; col : int; row : int }
  | Bail_collapse

type play_result = {
  wall : Mining_wall.wall;
  moves : int;
  bailed : bool;
  uncovered : Mining_goal.item list;
}

let scan_right_col = 11
let adj_table_capacity = 16
let cardinal_dirs = [ (-1, 0); (1, 0); (0, -1); (0, 1) ]
let pickaxe_kernel = [ (0, 0, 2); (-1, 0, 1); (1, 0, 1); (0, -1, 1); (0, 1, 1) ]

(* Sparse 3-tile-spaced Hammer anchors covering the 13x10 wall.
   Because Hammer hits a 3x3 area, these 12 points inspect nearly every 2x2+
   item footprint on the board. *)
let scan_anchors =
  [
    (2, 2);
    (5, 2);
    (8, 2);
    (scan_right_col, 2);
    (2, 5);
    (5, 5);
    (8, 5);
    (scan_right_col, 5);
    (2, 8);
    (5, 8);
    (8, 8);
    (scan_right_col, 8);
  ]

let is_iron (obs : Mining_wall.observation) ~col ~row =
  match obs.grid.(row).(col) with
  | Mining_wall.Clear_iron -> true
  | _ -> false

let dirt_at (obs : Mining_wall.observation) ~col ~row =
  match obs.grid.(row).(col) with
  | Mining_wall.Covered d -> d
  | _ -> 0

let record_exposed_cell tbl r c = function
  | Mining_wall.Clear_item { id; kind } ->
      let prev =
        match Hashtbl.find_opt tbl id with
        | Some (_, cells) -> cells
        | None -> []
      in
      Hashtbl.replace tbl id (kind, (c, r) :: prev)
  | _ -> ()

let exposed_items (obs : Mining_wall.observation) =
  let tbl = Hashtbl.create 8 in
  for r = 0 to obs.rows - 1 do
    for c = 0 to obs.cols - 1 do
      record_exposed_cell tbl r c obs.grid.(r).(c)
    done
  done;
  Hashtbl.fold (fun id (kind, cells) acc -> (id, kind, cells) :: acc) tbl []

let priority_rank = function
  | Mining_goal.Shard_l -> 0
  | Mining_goal.Shard_s -> 1
  | Mining_goal.Other -> 2

let add_covered_neighbors obs seen (c, r) =
  List.iter
    (fun (dc, dr) ->
      let nc = c + dc and nr = r + dr in
      if Mining_wall.in_bounds ~col:nc ~row:nr && dirt_at obs ~col:nc ~row:nr > 0 then
        Hashtbl.replace seen (nc, nr) ())
    cardinal_dirs

let adjacent_covered (obs : Mining_wall.observation) cells =
  let seen = Hashtbl.create adj_table_capacity in
  List.iter (add_covered_neighbors obs seen) cells;
  Hashtbl.fold (fun pt () acc -> pt :: acc) seen []

let score_pickaxe (obs : Mining_wall.observation) targets ~col ~row =
  if is_iron obs ~col ~row then -1
  else
    List.fold_left
      (fun acc (dc, dr, dmg) ->
        let c = col + dc and r = row + dr in
        if Mining_wall.in_bounds ~col:c ~row:r && List.mem (c, r) targets then
          acc + min dmg (dirt_at obs ~col:c ~row:r)
        else acc)
      0 pickaxe_kernel

let best_excavation_hit obs cells =
  let targets = adjacent_covered obs cells in
  let best =
    List.fold_left
      (fun acc (c, r) ->
        let s = score_pickaxe obs targets ~col:c ~row:r in
        match acc with
        | None when s > 0 -> Some (c, r, s)
        | Some (_, _, bs) when s > bs -> Some (c, r, s)
        | _ -> acc)
      None targets
  in
  Option.map (fun (col, row, _) -> Strike { tool = Pickaxe; col; row }) best

let find_wanted_excavation ~goal ~tally (obs : Mining_wall.observation) items =
  let wanted =
    List.filter
      (fun (id, kind, _) ->
        Mining_goal.wants_item goal tally kind
        && not (List.mem id obs.uncovered_ids))
      items
    |> List.sort (fun (_, k1, _) (_, k2, _) ->
           Int.compare (priority_rank k1) (priority_rank k2))
  in
  List.find_map (fun (_, _, cells) -> best_excavation_hit obs cells) wanted

let all_items_accounted_non_shard ~goal ~tally (obs : Mining_wall.observation) items =
  let any_wanted =
    List.exists (fun (_, kind, _) -> Mining_goal.wants_item goal tally kind) items
  in
  (not any_wanted) && List.length items >= obs.announced_items

let next_scan_anchor (obs : Mining_wall.observation) =
  let candidates =
    List.filter_map
      (fun (c, r) ->
        let d = dirt_at obs ~col:c ~row:r in
        if d > 0 && not (is_iron obs ~col:c ~row:r) then Some (c, r, d)
        else None)
      scan_anchors
  in
  match
    List.sort (fun (_, _, d1) (_, _, d2) -> Int.compare d1 d2) candidates
  with
  | (col, row, _) :: _ -> Some (Strike { tool = Hammer; col; row })
  | [] -> None

let decide ~goal ~tally (obs : Mining_wall.observation) =
  let items = exposed_items obs in
  match find_wanted_excavation ~goal ~tally obs items with
  | Some act -> act
  | None ->
      if all_items_accounted_non_shard ~goal ~tally obs items then Bail_collapse
      else
        match next_scan_anchor obs with
        | Some act -> act
        | None -> Bail_collapse

let collapse_wall wall moves =
  let rec loop w m =
    if Mining_wall.is_finished w then (w, m)
    else loop (Mining_wall.strike w ~tool:Hammer ~col:0 ~row:0) (m + 1)
  in
  loop wall moves

let play_wall ~goal ~tally wall =
  let rec loop w moves bailed =
    if Mining_wall.is_finished w then
      { wall = w; moves; bailed; uncovered = Mining_wall.uncovered_items w }
    else
      let obs = Mining_wall.observe w in
      match decide ~goal ~tally obs with
      | Bail_collapse ->
          let w', m' = collapse_wall w moves in
          { wall = w'; moves = m'; bailed = true; uncovered = Mining_wall.uncovered_items w' }
      | Strike { tool; col; row } ->
          let w' = Mining_wall.strike w ~tool ~col ~row in
          loop w' (moves + 1) bailed
  in
  loop wall 0 false
