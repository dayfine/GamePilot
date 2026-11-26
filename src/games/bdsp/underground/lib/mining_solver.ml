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
let anchor_covered_weight = 4
let anchor_iron_penalty = 6
let cardinal_dirs = [ (-1, 0); (1, 0); (0, -1); (0, 1) ]

let ring_offsets radius =
  let acc = ref [] in
  for dr = -radius to radius do
    for dc = -radius to radius do
      if dc <> 0 || dr <> 0 then acc := (dc, dr) :: !acc
    done
  done;
  !acc

let chebyshev_r1 = ring_offsets 1
let chebyshev_r2 = ring_offsets shard_expand_radius
let pickaxe_kernel = [ (0, 0, 2); (-1, 0, 1); (1, 0, 1); (0, -1, 1); (0, 1, 1) ]

let hammer_kernel =
  [
    (0, 0, 2);
    (-1, 0, 2);
    (1, 0, 2);
    (0, -1, 2);
    (0, 1, 2);
    (-1, -1, 1);
    (1, -1, 1);
    (-1, 1, 1);
    (1, 1, 1);
  ]

(* Sparse 3-tile-spaced Hammer anchors covering the 13x10 wall.
   Because Hammer hits a 3x3 area, these 12 points inspect nearly every 2x2+
   item footprint on the board without interior gaps. *)
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
  match obs.grid.(row).(col) with Mining_wall.Clear_iron -> true | _ -> false

let dirt_at (obs : Mining_wall.observation) ~col ~row =
  match obs.grid.(row).(col) with Mining_wall.Covered d -> d | _ -> 0

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

(* Compare Pickaxe (cost 1) vs Hammer (cost 2) using scaled efficiency
   (target dirt cleared * 2 / cost). Prefer Hammer only when the center has >= 2
   dirt layers, Hammer hits >= 3 covered target cells, integrity >= 4, and
   Hammer clears at least as much target dirt per integrity point as Pickaxe. *)
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
  (not any_wanted) && List.length items >= obs.announced_items

let score_scan_anchor (obs : Mining_wall.observation) ~col ~row =
  let covered, iron =
    List.fold_left
      (fun (cov, ir) (dc, dr, _) ->
        let c = col + dc and r = row + dr in
        if not (Mining_wall.in_bounds ~col:c ~row:r) then (cov, ir)
        else if is_iron obs ~col:c ~row:r then (cov, ir + 1)
        else if dirt_at obs ~col:c ~row:r > 0 then (cov + 1, ir)
        else (cov, ir))
      (0, 0) hammer_kernel
  in
  (covered * anchor_covered_weight)
  - (iron * anchor_iron_penalty)
  - dirt_at obs ~col ~row

let next_scan_anchor (obs : Mining_wall.observation) =
  let candidates =
    List.filter_map
      (fun (c, r) ->
        let d = dirt_at obs ~col:c ~row:r in
        if d > 0 && not (is_iron obs ~col:c ~row:r) then
          Some (c, r, score_scan_anchor obs ~col:c ~row:r)
        else None)
      scan_anchors
  in
  match
    List.sort (fun (_, _, s1) (_, _, s2) -> Int.compare s2 s1) candidates
  with
  | (col, row, _) :: _ -> Some (Strike { tool = Hammer; col; row })
  | [] -> None

let covered_neighbor_count obs (_, _, cells) =
  List.length (adjacent_covered ~offsets:cardinal_dirs obs cells)

let sort_easiest_first obs items =
  List.sort
    (fun a b ->
      Int.compare (covered_neighbor_count obs a) (covered_neighbor_count obs b))
    items

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

let decide_after_scan obs items =
  match find_secondary_excavation obs items with
  | Some act -> act
  | None -> Bail_collapse

let decide_low_gauge obs items =
  match find_secondary_excavation obs items with
  | Some act -> act
  | None -> (
      match next_scan_anchor obs with Some act -> act | None -> Bail_collapse)

let decide ~goal ~tally (obs : Mining_wall.observation) =
  let items = exposed_items obs in
  match find_wanted_excavation ~goal ~tally obs items with
  | Some act -> act
  | None -> (
      if all_items_accounted_non_shard ~goal ~tally obs items then
        decide_after_scan obs items
      else if obs.integrity <= low_gauge_cutoff then decide_low_gauge obs items
      else
        match next_scan_anchor obs with
        | Some act -> act
        | None -> decide_after_scan obs items)

let collapse_wall wall moves =
  let rec loop w m =
    if Mining_wall.is_finished w then (w, m)
    else loop (Mining_wall.strike w ~tool:Hammer ~col:0 ~row:0) (m + 1)
  in
  loop wall moves

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
