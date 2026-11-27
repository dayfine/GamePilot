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
let adj_table_capacity = 24
let min_secondary_integrity = 4
let min_hammer_excavate_integrity = 4
let min_hammer_target_dirt = 2
let min_hammer_target_hits = 3
let low_gauge_cutoff = 18
let shard_expand_radius = 2
let scan_expose_weight = 6
let scan_crack_weight = 2
let anchor_iron_penalty = 6
let cardinal_dirs = [ (-1, 0); (1, 0); (0, -1); (0, 1) ]

let ring_offsets radius =
  let span = List.init ((2 * radius) + 1) (fun i -> i - radius) in
  List.concat_map
    (fun dr ->
      List.filter_map
        (fun dc -> if dc = 0 && dr = 0 then None else Some (dc, dr))
        span)
    span

let chebyshev_r1 = ring_offsets 1
let chebyshev_r2 = ring_offsets shard_expand_radius
let pickaxe_kernel = [ (0, 0, 2); (-1, 0, 1); (1, 0, 1); (0, -1, 1); (0, 1, 1) ]

let hammer_kernel =
  (0, 0, 2)
  :: List.map
       (fun (dc, dr) -> (dc, dr, if dc = 0 || dr = 0 then 2 else 1))
       chebyshev_r1

let scan_cols = [ 2; 5; 8; scan_right_col ]
let scan_rows = [ 2; 5; 8 ]

let scan_anchors =
  List.concat_map (fun r -> List.map (fun c -> (c, r)) scan_cols) scan_rows

let is_iron (obs : Mining_wall.observation) ~col ~row =
  match obs.grid.(row).(col) with Mining_wall.Clear_iron -> true | _ -> false

let dirt_at (obs : Mining_wall.observation) ~col ~row =
  match obs.grid.(row).(col) with Mining_wall.Covered d -> d | _ -> 0

let record_exposed_cell tbl r c = function
  | Mining_wall.Clear_item { id; kind } ->
      let prev = Option.fold ~none:[] ~some:snd (Hashtbl.find_opt tbl id) in
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
  | Shard_s -> 1
  | Other -> 2

let add_covered_neighbors ~offsets obs seen (c, r) =
  List.iter
    (fun (dc, dr) ->
      let nc = c + dc and nr = r + dr in
      if
        Mining_wall.in_bounds ~col:nc ~row:nr && dirt_at obs ~col:nc ~row:nr > 0
      then Hashtbl.replace seen (nc, nr) ())
    offsets

let adjacent_covered ~offsets (obs : Mining_wall.observation) cells =
  let seen = Hashtbl.create adj_table_capacity in
  List.iter (add_covered_neighbors ~offsets obs seen) cells;
  Hashtbl.fold (fun pt () acc -> pt :: acc) seen []

let add_kernel_hit obs targets ~col ~row (dmg_acc, hit_acc) (dc, dr, dmg) =
  let c = col + dc and r = row + dr in
  if
    Mining_wall.in_bounds ~col:c ~row:r
    && List.mem (c, r) targets
    && dirt_at obs ~col:c ~row:r > 0
  then (dmg_acc + min dmg (dirt_at obs ~col:c ~row:r), hit_acc + 1)
  else (dmg_acc, hit_acc)

let score_kernel kernel (obs : Mining_wall.observation) targets ~col ~row =
  if is_iron obs ~col ~row then (0, 0)
  else List.fold_left (add_kernel_hit obs targets ~col ~row) (0, 0) kernel

(* Compare Pickaxe vs Hammer efficiency (target dirt * 2 / cost). *)
let choose_excavation_tool (obs : Mining_wall.observation) targets ~col ~row =
  let p_dmg, _ = score_kernel pickaxe_kernel obs targets ~col ~row in
  let h_dmg, h_hits = score_kernel hammer_kernel obs targets ~col ~row in
  let p_eff = p_dmg * Mining_wall.hammer_cost in
  let can_hammer =
    obs.integrity >= min_hammer_excavate_integrity
    && dirt_at obs ~col ~row >= min_hammer_target_dirt
    && h_hits >= min_hammer_target_hits
    && h_dmg >= p_eff
  in
  if can_hammer then (Mining_wall.Hammer, h_dmg)
  else (Mining_wall.Pickaxe, p_eff)

let best_excavation_hit ~offsets obs cells =
  let targets = adjacent_covered ~offsets obs cells in
  let best =
    List.fold_left
      (fun acc (c, r) ->
        let tool, score = choose_excavation_tool obs targets ~col:c ~row:r in
        match acc with
        | None when score > 0 -> Some (tool, c, r, score)
        | Some (_, _, _, bs) when score > bs -> Some (tool, c, r, score)
        | _ -> acc)
      None targets
  in
  Option.map (fun (tool, col, row, _) -> Strike { tool; col; row }) best

let excavate_wanted_cells obs cells =
  match best_excavation_hit ~offsets:chebyshev_r1 obs cells with
  | Some _ as hit -> hit
  | None -> best_excavation_hit ~offsets:chebyshev_r2 obs cells

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
  List.find_map (fun (_, _, cells) -> excavate_wanted_cells obs cells) wanted

let all_items_accounted_non_shard ~goal ~tally (obs : Mining_wall.observation)
    items =
  let any_wanted =
    List.exists
      (fun (_, kind, _) -> Mining_goal.wants_item goal tally kind)
      items
  in
  let real_other =
    List.filter (fun (_, _, cells) -> List.length cells >= 2) items
  in
  (not any_wanted) && List.length real_other >= obs.announced_items

let mark_cell_footprint tbl (c, r) =
  Hashtbl.replace tbl (c, r) ();
  List.iter
    (fun (dc, dr) -> Hashtbl.replace tbl (c + dc, r + dr) ())
    chebyshev_r1

(* Cells within Chebyshev distance 1 of an exposed non-wanted item: we infer
   its footprint covers these neighbors and avoid wasting scan hits on them. *)
let unwanted_footprint ~goal ~tally items =
  let tbl = Hashtbl.create adj_table_capacity in
  let add (_, kind, cells) =
    if not (Mining_goal.wants_item goal tally kind) then
      List.iter (mark_cell_footprint tbl) cells
  in
  List.iter add items;
  tbl

let scan_dirt_cell (exp, crk, ir) dmg d =
  if d <= 0 then (exp, crk, ir)
  else (exp + Bool.to_int (d <= dmg), crk + min dmg d, ir)

let scan_cell ~avoid (obs : Mining_wall.observation) ~col ~row (exp, crk, ir)
    (dc, dr, dmg) =
  let c = col + dc and r = row + dr in
  if not (Mining_wall.in_bounds ~col:c ~row:r) then (exp, crk, ir)
  else if is_iron obs ~col:c ~row:r then (exp, crk, ir + 1)
  else if Hashtbl.mem avoid (c, r) then (exp, crk, ir)
  else scan_dirt_cell (exp, crk, ir) dmg (dirt_at obs ~col:c ~row:r)

let score_scan_kernel ~avoid kernel cost obs ~col ~row =
  let exp, crk, ir =
    List.fold_left (scan_cell ~avoid obs ~col ~row) (0, 0, 0) kernel
  in
  let raw =
    (exp * scan_expose_weight) + (crk * scan_crack_weight)
    - (ir * anchor_iron_penalty)
  in
  raw * Mining_wall.hammer_cost / cost

let best_scan_tool ~avoid obs ~col ~row =
  let p =
    score_scan_kernel ~avoid pickaxe_kernel Mining_wall.pickaxe_cost obs ~col
      ~row
  in
  let h =
    if obs.integrity < Mining_wall.hammer_cost then min_int
    else
      score_scan_kernel ~avoid hammer_kernel Mining_wall.hammer_cost obs ~col
        ~row
  in
  if h > p then (Mining_wall.Hammer, h) else (Mining_wall.Pickaxe, p)

let all_wall_cells =
  List.concat_map
    (fun r -> List.init Mining_wall.cols (fun c -> (c, r)))
    (List.init Mining_wall.rows Fun.id)

let best_scan_in ~avoid (obs : Mining_wall.observation) cells =
  let pick best (c, r) =
    if dirt_at obs ~col:c ~row:r <= 0 || is_iron obs ~col:c ~row:r then best
    else
      let tool, score = best_scan_tool ~avoid obs ~col:c ~row:r in
      match best with
      | Some (_, _, _, bs) when score <= bs -> best
      | _ when score > 0 -> Some (tool, c, r, score)
      | _ -> best
  in
  Option.map
    (fun (tool, col, row, _) -> Strike { tool; col; row })
    (List.fold_left pick None cells)

let next_scan_anchor ~goal ~tally (obs : Mining_wall.observation) items =
  let avoid = unwanted_footprint ~goal ~tally items in
  match best_scan_in ~avoid obs scan_anchors with
  | Some _ as hit -> hit
  | None -> best_scan_in ~avoid obs all_wall_cells

let sort_easiest_first obs items =
  let cov (_, _, cells) =
    List.length (adjacent_covered ~offsets:cardinal_dirs obs cells)
  in
  List.sort (fun a b -> Int.compare (cov a) (cov b)) items

let find_secondary_excavation (obs : Mining_wall.observation) items =
  if obs.integrity < min_secondary_integrity then None
  else
    let pending =
      List.filter (fun (id, _, _) -> not (List.mem id obs.uncovered_ids)) items
    in
    List.find_map
      (fun (_, _, cells) ->
        best_excavation_hit ~offsets:cardinal_dirs obs cells)
      (sort_easiest_first obs pending)

let decide_low_gauge ~goal ~tally obs items =
  match find_secondary_excavation obs items with
  | Some act -> act
  | None ->
      Option.value
        (next_scan_anchor ~goal ~tally obs items)
        ~default:Bail_collapse

let decide ~goal ~tally (obs : Mining_wall.observation) =
  let items = exposed_items obs in
  let secondary () =
    Option.value (find_secondary_excavation obs items) ~default:Bail_collapse
  in
  match find_wanted_excavation ~goal ~tally obs items with
  | Some act -> act
  | None -> (
      if all_items_accounted_non_shard ~goal ~tally obs items then secondary ()
      else if obs.integrity <= low_gauge_cutoff then
        decide_low_gauge ~goal ~tally obs items
      else
        match next_scan_anchor ~goal ~tally obs items with
        | Some act -> act
        | None -> secondary ())

let rec collapse_wall wall moves =
  if Mining_wall.is_finished wall then (wall, moves)
  else
    collapse_wall
      (Mining_wall.strike wall ~tool:Hammer ~col:0 ~row:0)
      (moves + 1)

let finish_play ~bailed wall moves =
  { wall; moves; bailed; uncovered = Mining_wall.uncovered_items wall }

let rec play_loop ~goal ~tally w moves =
  if Mining_wall.is_finished w then finish_play ~bailed:false w moves
  else
    match decide ~goal ~tally (Mining_wall.observe w) with
    | Bail_collapse ->
        let w', m' = collapse_wall w moves in
        finish_play ~bailed:true w' m'
    | Strike { tool; col; row } ->
        play_loop ~goal ~tally (Mining_wall.strike w ~tool ~col ~row) (moves + 1)

let play_wall ~goal ~tally wall = play_loop ~goal ~tally wall 0
