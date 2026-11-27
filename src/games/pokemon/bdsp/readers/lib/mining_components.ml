open Bdsp_underground

let cols = Mining_wall.cols
let rows = Mining_wall.rows
let neighbor_offsets = [ (-1, 0); (1, 0); (0, -1); (0, 1) ]
let min_uncovered_cells = 2
let initial_component_buckets = 8

let try_visit_neighbor grid visited kind comp_id (c, r) acc (dc, dr) =
  let nc = c + dc and nr = r + dr in
  if (not (Mining_wall.in_bounds ~col:nc ~row:nr)) || visited.(nr).(nc) then acc
  else
    match grid.(nr).(nc) with
    | Mining_wall.Clear_item { kind = k; _ } when k = kind ->
        visited.(nr).(nc) <- true;
        grid.(nr).(nc) <- Mining_wall.Clear_item { id = comp_id; kind };
        (nc, nr) :: acc
    | _ -> acc

let expand_point grid visited kind comp_id rest pt =
  List.fold_left
    (try_visit_neighbor grid visited kind comp_id pt)
    rest neighbor_offsets

let rec flood_component grid visited kind comp_id = function
  | [] -> ()
  | pt :: rest ->
      let next = expand_point grid visited kind comp_id rest pt in
      flood_component grid visited kind comp_id next

let start_component grid visited next_id r c =
  if visited.(r).(c) then ()
  else
    match grid.(r).(c) with
    | Mining_wall.Clear_item { kind; _ } ->
        let id = !next_id in
        incr next_id;
        visited.(r).(c) <- true;
        grid.(r).(c) <- Mining_wall.Clear_item { id; kind };
        flood_component grid visited kind id [ (c, r) ]
    | _ -> ()

let label_item_components grid =
  let visited = Array.init rows (fun _ -> Array.make cols false) in
  let next_id = ref 1 in
  for r = 0 to rows - 1 do
    for c = 0 to cols - 1 do
      start_component grid visited next_id r c
    done
  done

let has_covered_neighbor grid (c, r) =
  List.exists
    (fun (dc, dr) ->
      let nc = c + dc and nr = r + dr in
      Mining_wall.in_bounds ~col:nc ~row:nr
      && match grid.(nr).(nc) with Mining_wall.Covered _ -> true | _ -> false)
    neighbor_offsets

let infer_uncovered_ids grid =
  let tbl = Hashtbl.create initial_component_buckets in
  for r = 0 to rows - 1 do
    for c = 0 to cols - 1 do
      match grid.(r).(c) with
      | Mining_wall.Clear_item { id; _ } ->
          let prev = Option.value (Hashtbl.find_opt tbl id) ~default:[] in
          Hashtbl.replace tbl id ((c, r) :: prev)
      | _ -> ()
    done
  done;
  Hashtbl.fold
    (fun id cells acc ->
      if
        List.length cells >= min_uncovered_cells
        && not (List.exists (has_covered_neighbor grid) cells)
      then id :: acc
      else acc)
    tbl []

let label_and_infer_uncovered grid =
  label_item_components grid;
  infer_uncovered_ids grid
