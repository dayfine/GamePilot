type arrive = Held of int | First_read
type kind = Transit | Acts of string

type 'screen edge = {
  input : Wire.command list;
  leads_to : 'screen;
  arrive : arrive;
  within_ms : int;
  kind : kind;
}

type when_unread = Fail | Press of Wire.command list

type 'screen t = {
  name : string;
  probes : Wire.probe_spec list;
  read : Wire.frame -> 'screen list;
  edges : 'screen -> 'screen edge list;
  screens : 'screen list;
  home : 'screen;
  when_unread : when_unread;
  show : 'screen -> string;
  describe : Wire.frame -> string;
}

let exactly target s = s = target

let transit_edges graph s =
  List.filter (fun e -> e.kind = Transit) (graph.edges s)

let find_act graph ~from name =
  List.find_opt
    (fun e -> match e.kind with Acts n -> n = name | Transit -> false)
    (graph.edges from)

let enqueue_neighbors graph ~visited ~queue rev_path current =
  List.fold_left
    (fun (vis, q) edge ->
      if List.mem edge.leads_to vis then (vis, q)
      else (edge.leads_to :: vis, q @ [ (edge.leads_to, edge :: rev_path) ]))
    (visited, queue)
    (transit_edges graph current)

let rec bfs graph ~at visited = function
  | [] -> None
  | (current, rev_path) :: _ when at current -> Some (List.rev rev_path)
  | (current, rev_path) :: rest ->
      let visited, queue =
        enqueue_neighbors graph ~visited ~queue:rest rev_path current
      in
      bfs graph ~at visited queue

let path graph ~from ~at =
  if at from then Some [] else bfs graph ~at [ from ] [ (from, []) ]

let check_home graph =
  if List.mem graph.home graph.screens then Ok ()
  else
    Error
      (Printf.sprintf "%s: home screen %s is not in screens" graph.name
         (graph.show graph.home))

let check_edge_targets graph screen =
  let bad =
    List.find_opt
      (fun e -> not (List.mem e.leads_to graph.screens))
      (graph.edges screen)
  in
  match bad with
  | None -> Ok ()
  | Some e ->
      Error
        (Printf.sprintf "%s: edge from %s leads to %s, which is not in screens"
           graph.name (graph.show screen) (graph.show e.leads_to))

let rec first_duplicate seen = function
  | [] -> None
  | x :: _ when List.mem x seen -> Some x
  | x :: rest -> first_duplicate (x :: seen) rest

let check_unique_acts graph screen =
  let act_names =
    List.filter_map
      (fun e -> match e.kind with Acts n -> Some n | Transit -> None)
      (graph.edges screen)
  in
  match first_duplicate [] act_names with
  | None -> Ok ()
  | Some dup ->
      Error
        (Printf.sprintf "%s: duplicate act %S on screen %s" graph.name dup
           (graph.show screen))

let check_reaches_home graph screen =
  match path graph ~from:screen ~at:(exactly graph.home) with
  | Some _ -> Ok ()
  | None ->
      Error
        (Printf.sprintf "%s: screen %s cannot reach home (%s) via Transit edges"
           graph.name (graph.show screen) (graph.show graph.home))

let check_screen graph screen =
  let ( let* ) = Result.bind in
  let* () = check_edge_targets graph screen in
  let* () = check_unique_acts graph screen in
  check_reaches_home graph screen

let check graph =
  let ( let* ) = Result.bind in
  let* () = check_home graph in
  List.fold_left
    (fun acc screen -> Result.bind acc (fun () -> check_screen graph screen))
    (Ok ()) graph.screens
