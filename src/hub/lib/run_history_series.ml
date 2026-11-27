type run = { run : string; result : string; at : string; reason : string }
type checkpoint = { id : string; state : string; runs : run list }

type t = {
  series : string;
  game : string;
  game_name : string;
  program : string;
  program_name : string;
  group : string;
  from : string;
  to_ : string;
  mode : string;
  backend : string;
  started_ms : int;
  ended_ms : int;
  result : string;
  active_run : string;
  checkpoints : checkpoint list;
}

let make_run fs run =
  {
    run;
    result = Run_history_parse.json_str fs "result";
    at = Run_history_parse.json_str fs "at";
    reason = Run_history_parse.json_str fs "reason";
  }

let parse_run = function
  | `Assoc fs ->
      let run = Run_history_parse.json_str fs "run" in
      if run = "" then None else Some (make_run fs run)
  | _ -> None

let json_list fs key =
  match List.assoc_opt key fs with Some (`List items) -> items | _ -> []

let parse_checkpoint = function
  | `Assoc fs ->
      let runs = List.filter_map parse_run (json_list fs "runs") in
      let id = Run_history_parse.json_str fs "id" in
      let state = Run_history_parse.json_str fs "state" in
      Some { id; state; runs }
  | _ -> None

let make_series fs series =
  let s = Run_history_parse.json_str fs in
  let checkpoints =
    List.filter_map parse_checkpoint (json_list fs "checkpoints")
  in
  {
    series;
    game = s "game";
    game_name = s "game_name";
    program = s "program";
    program_name = s "program_name";
    group = s "group";
    from = s "from";
    to_ = s "to";
    mode = s "mode";
    backend = s "backend";
    started_ms = Run_history_parse.json_int fs "started_ms" 0;
    ended_ms = Run_history_parse.json_int fs "ended_ms" 0;
    result = s "result";
    active_run = s "run";
    checkpoints;
  }

let parse = function
  | `Assoc fs ->
      let series = Run_history_parse.json_str fs "series" in
      if Run_history_parse.valid_run_name series then
        Some (make_series fs series)
      else None
  | _ -> None

let child_runs s =
  let cp_runs =
    List.concat_map (fun c -> List.map (fun r -> r.run) c.runs) s.checkpoints
  in
  if s.active_run <> "" then s.active_run :: cp_runs else cp_runs

let focus_checkpoint s =
  let find_state st =
    List.find_map
      (fun c -> if c.state = st then Some c.id else None)
      s.checkpoints
  in
  match find_state "failed" with
  | Some id -> id
  | None -> Option.value (find_state "current") ~default:""

let first_failed_run (runs : run list) =
  List.find_opt (fun (r : run) -> r.result = "fail") runs

let failure s =
  if s.result <> "fail" then ("", "")
  else
    let from_failed =
      List.find_map
        (fun c -> if c.state = "failed" then first_failed_run c.runs else None)
        s.checkpoints
    in
    let found =
      match from_failed with
      | Some _ as r -> r
      | None -> List.find_map (fun c -> first_failed_run c.runs) s.checkpoints
    in
    match found with Some (r : run) -> (r.at, r.reason) | None -> ("", "")

let read_json_file path =
  if Sys.is_directory path then None
  else
    match Repo_io.Json_file.read path with
    | Ok json -> parse json
    | Error _ -> None

let read_file series_dir name =
  if String.ends_with ~suffix:".json" name then
    read_json_file (Filename.concat series_dir name)
  else None

let read_dir ~runs_dir =
  let series_dir =
    Filename.concat (Filename.concat runs_dir ".watch") "series"
  in
  if not (Sys.file_exists series_dir && Sys.is_directory series_dir) then []
  else
    Sys.readdir series_dir |> Array.to_list
    |> List.filter_map (read_file series_dir)

let has_recorded_frames dir =
  Sys.file_exists (Filename.concat (Filename.concat dir "frames") "index.jsonl")

let any_recorded ~runs_dir s =
  List.exists
    (fun r -> has_recorded_frames (Filename.concat runs_dir r))
    (child_runs s)

module String_set = Set.Make (String)

let covered_runs series =
  let add_all acc s =
    List.fold_left (Fun.flip String_set.add) acc (child_runs s)
  in
  List.fold_left add_all String_set.empty series
