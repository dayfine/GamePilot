let plan_suffix = ".plan.json"

let checkpoint_ids dir =
  match Sys.readdir dir with
  | names ->
      Ok
        (Array.to_list names
        |> List.filter (fun n -> Filename.check_suffix n plan_suffix)
        |> List.map (fun n -> Filename.chop_suffix n plan_suffix)
        |> List.sort Checkpoint_order.compare)
  | exception Sys_error e -> Error e

let rec drop_until id = function
  | [] -> []
  | x :: rest as all -> if x = id then all else drop_until id rest

let resolve ids id =
  if List.mem id ids then Ok id
  else
    match List.filter (String.starts_with ~prefix:(id ^ "-")) ids with
    | [ named ] -> Ok named
    | [] -> Error ("no checkpoint " ^ id)
    | named ->
        Error
          (id ^ " names more than one checkpoint: " ^ String.concat ", " named)

let select ids ~from_id ~to_id =
  let ( let* ) = Result.bind in
  let* from_id = resolve ids from_id in
  let* to_id = resolve ids to_id in
  let from = drop_until from_id ids in
  match (from, drop_until to_id from) with
  | [], _ -> Error ("no checkpoint " ^ from_id)
  | _, [] -> Error ("no checkpoint " ^ to_id ^ " at or after " ^ from_id)
  | _, _ :: after ->
      let n = List.length from - List.length after in
      Ok (List.filteri (fun i _ -> i < n) from, List.nth_opt after 0)

let plan_file ~plan_dir id = Filename.concat plan_dir (id ^ plan_suffix)

let previous ids id =
  let rec go prev = function
    | [] -> None
    | x :: rest -> if x = id then prev else go (Some x) rest
  in
  go None ids
