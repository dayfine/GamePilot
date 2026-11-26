type tool = Hammer | Pickaxe

type buried_item = {
  id : int;
  kind : Mining_goal.item;
  cells : (int * int) list;
}

type cell_content = Empty | Iron | Item of int

type visible_cell =
  | Covered of int
  | Clear_empty
  | Clear_iron
  | Clear_item of { id : int; kind : Mining_goal.item }

type wall = {
  dirt : int array array;
  content : cell_content array array;
  items : buried_item list;
  integrity : int;
}

type observation = {
  cols : int;
  rows : int;
  integrity : int;
  collapsed : bool;
  announced_items : int;
  grid : visible_cell array array;
  uncovered_ids : int list;
}

let cols = 13
let rows = 10
let max_integrity = 49
let hammer_cost = 2
let pickaxe_cost = 1
let max_dirt_layer = 6
let lcg_mult = 1103515245
let lcg_inc = 12345
let lcg_mask = 0x7fffffff
let lcg_shift = 16
let lcg_out_mask = 0x7fff
let max_place_attempts = 40

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

let tool_cost = function Hammer -> hammer_cost | Pickaxe -> pickaxe_cost
let damage_kernel = function Pickaxe -> pickaxe_kernel | Hammer -> hammer_kernel
let in_bounds ~col ~row = col >= 0 && col < cols && row >= 0 && row < rows
let copy_grid g = Array.init (Array.length g) (fun r -> Array.copy g.(r))

let item_uncovered dirt item =
  List.for_all (fun (c, r) -> dirt.(r).(c) = 0) item.cells

let uncovered_ids_of (w : wall) =
  List.filter_map
    (fun it -> if item_uncovered w.dirt it then Some it.id else None)
    w.items

let is_finished (w : wall) =
  w.integrity <= 0
  || List.for_all (fun it -> item_uncovered w.dirt it) w.items

let integrity (w : wall) = w.integrity
let all_items (w : wall) = w.items

let uncovered_items (w : wall) =
  List.filter_map
    (fun it -> if item_uncovered w.dirt it then Some it.kind else None)
    w.items

let find_item_kind items id =
  match List.find_opt (fun it -> it.id = id) items with
  | Some it -> it.kind
  | None -> Mining_goal.Other

let observe_cell (w : wall) r c =
  let d = w.dirt.(r).(c) in
  if d > 0 then Covered d
  else
    match w.content.(r).(c) with
    | Empty -> Clear_empty
    | Iron -> Clear_iron
    | Item id -> Clear_item { id; kind = find_item_kind w.items id }

let observe (w : wall) =
  let grid = Array.init rows (fun r -> Array.init cols (observe_cell w r)) in
  {
    cols;
    rows;
    integrity = w.integrity;
    collapsed = w.integrity <= 0;
    announced_items = List.length w.items;
    grid;
    uncovered_ids = uncovered_ids_of w;
  }

let ( let* ) = Result.bind

let validate_dirt dirt =
  if Array.length dirt <> rows then Error "dirt must have 10 rows"
  else if Array.exists (fun row -> Array.length row <> cols) dirt then
    Error "every dirt row must have 13 columns"
  else Ok ()

let rec place_cells content value = function
  | [] -> Ok ()
  | (c, r) :: rest ->
      if not (in_bounds ~col:c ~row:r) then Error "coordinate out of bounds"
      else (
        content.(r).(c) <- value;
        place_cells content value rest)

let rec place_all_items content = function
  | [] -> Ok ()
  | it :: rest ->
      let* () = place_cells content (Item it.id) it.cells in
      place_all_items content rest

let clamp_dirt dirt =
  Array.init rows (fun r ->
      Array.init cols (fun c -> max 0 (min max_dirt_layer dirt.(r).(c))))

let make ~dirt ~iron ~items =
  let* () = validate_dirt dirt in
  let content = Array.init rows (fun _ -> Array.make cols Empty) in
  let* () = place_cells content Iron iron in
  let* () = place_all_items content items in
  Ok { dirt = clamp_dirt dirt; content; items; integrity = max_integrity }

let hit_hits_iron (w : wall) ~col ~row =
  in_bounds ~col ~row && w.dirt.(row).(col) = 0 && w.content.(row).(col) = Iron

let apply_damage dirt ~tool ~col ~row =
  List.iter
    (fun (dc, dr, dmg) ->
      let c = col + dc and r = row + dr in
      if in_bounds ~col:c ~row:r then
        dirt.(r).(c) <- max 0 (dirt.(r).(c) - dmg))
    (damage_kernel tool)

let strike (w : wall) ~tool ~col ~row =
  if is_finished w || not (in_bounds ~col ~row) then w
  else
    let next_integrity = max 0 (w.integrity - tool_cost tool) in
    let dirt = copy_grid w.dirt in
    if not (hit_hits_iron w ~col ~row) then apply_damage dirt ~tool ~col ~row;
    { w with dirt; integrity = next_integrity }

let next_rand state =
  let next = ((state * lcg_mult) + lcg_inc) land lcg_mask in
  (next, (next lsr lcg_shift) land lcg_out_mask)

let footprint_for = function
  | Mining_goal.Shard_s -> [ (0, 0); (1, 0); (0, 1); (1, 1) ]
  | Mining_goal.Shard_l ->
      [ (0, 0); (1, 0); (2, 0); (3, 0); (0, 1); (1, 1); (2, 1); (3, 1) ]
  | Mining_goal.Other -> [ (0, 0); (1, 0); (2, 0); (0, 1); (1, 1); (2, 1) ]

let can_place occupied cells =
  List.for_all
    (fun (c, r) -> in_bounds ~col:c ~row:r && not occupied.(r).(c))
    cells

let mark_occupied occupied cells =
  List.iter (fun (c, r) -> occupied.(r).(c) <- true) cells

let try_place_item rng occupied id kind =
  let shape = footprint_for kind in
  let rec attempt rng tries =
    if tries = 0 then (rng, None)
    else
      let rng, rx = next_rand rng in
      let rng, ry = next_rand rng in
      let c0 = rx mod cols and r0 = ry mod rows in
      let cells = List.map (fun (dc, dr) -> (c0 + dc, r0 + dr)) shape in
      if can_place occupied cells then (
        mark_occupied occupied cells;
        (rng, Some { id; kind; cells }))
      else attempt rng (tries - 1)
  in
  attempt rng max_place_attempts

let generate ~seed ~items =
  let rng = ref (abs seed + 1) in
  let draw () =
    let s, v = next_rand !rng in
    rng := s;
    v
  in
  let dirt = Array.init rows (fun _ -> Array.init cols (fun _ -> 2 + (draw () mod 3))) in
  let occupied = Array.init rows (fun _ -> Array.make cols false) in
  let buried =
    List.mapi
      (fun idx kind ->
        let next_s, placed = try_place_item !rng occupied idx kind in
        rng := next_s;
        placed)
      items
    |> List.filter_map Fun.id
  in
  let iron_c = 1 + (draw () mod (cols - 3)) in
  let iron_r = 1 + (draw () mod (rows - 2)) in
  let iron_cand = [ (iron_c, iron_r); (iron_c + 1, iron_r) ] in
  let iron = if can_place occupied iron_cand then iron_cand else [] in
  match make ~dirt ~iron ~items:buried with
  | Ok w -> w
  | Error _ ->
      {
        dirt;
        content = Array.init rows (fun _ -> Array.make cols Empty);
        items = [];
        integrity = max_integrity;
      }
