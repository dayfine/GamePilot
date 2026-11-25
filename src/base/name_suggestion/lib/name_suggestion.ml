let distance a b =
  let n = String.length b in
  let row = Array.init (n + 1) Fun.id in
  String.iteri
    (fun i ca ->
      let diagonal = ref row.(0) in
      row.(0) <- i + 1;
      for j = 1 to n do
        let above = row.(j) in
        let cost = if ca = b.[j - 1] then 0 else 1 in
        row.(j) <- min (min (above + 1) (row.(j - 1) + 1)) (!diagonal + cost);
        diagonal := above
      done)
    a;
  row.(n)

let closest name known =
  let limit = max 2 (String.length name / 3) in
  let near =
    List.map (fun k -> (distance name k, k)) known
    |> List.filter (fun (d, _) -> d <= limit)
  in
  let best = List.fold_left (fun m (d, _) -> min m d) max_int near in
  List.filter_map (fun (d, k) -> if d = best then Some k else None) near
  |> List.sort compare

let unknown ~what name known =
  let missing = Printf.sprintf "no %s \"%s\"" what name in
  match closest name known with
  | [] -> missing
  | near -> missing ^ "; did you mean " ^ String.concat " or " near ^ "?"
