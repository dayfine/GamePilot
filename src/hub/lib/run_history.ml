type entry = {
  run : string;
  kind : string;
  game : string;
  game_name : string;
  program : string;
  program_name : string;
  group : string;
  checkpoint : string;
  from : string;
  to_ : string;
  backend : string;
  mode : string;
  result : string;
  at : string;
  reason : string;
  started_ms : int;
  ended_ms : int;
  recorded : bool;
}

let default_limit = 500
let watch_hub_port = 47901
let initial_tbl_size = 64
let ms_per_sec = 1000

let empty_entry run =
  {
    run;
    kind = "";
    game = "";
    game_name = "";
    program = "";
    program_name = "";
    group = "";
    checkpoint = "";
    from = "";
    to_ = "";
    backend = "";
    mode = "";
    result = "";
    at = "";
    reason = "";
    started_ms = 0;
    ended_ms = 0;
    recorded = false;
  }

let fallback_str cur v = if cur <> "" then cur else v
let overlay_str cur v = if v <> "" then v else cur

let apply_program e (p : Program_registry.t) =
  {
    e with
    game = fallback_str e.game p.game.game_id;
    game_name = fallback_str e.game_name p.game.game_name;
    program = fallback_str e.program p.id;
    program_name = fallback_str e.program_name p.name;
    group = fallback_str e.group (Program_registry.category_name p.category);
  }

let enrich_program e =
  let e =
    match
      Run_history_parse.lookup_program ~program:e.program
        ~checkpoint:e.checkpoint
    with
    | Some p -> apply_program e p
    | None -> e
  in
  let game =
    fallback_str e.game
      (fallback_str
         (Run_history_parse.infer_game_from_id e.program)
         (Run_history_parse.infer_game_from_id e.checkpoint))
  in
  let game_name =
    fallback_str e.game_name (Run_history_parse.game_name_of_id game)
  in
  { e with game; game_name }

let apply_tsv_row e (row : Run_history_parse.tsv_row) =
  {
    e with
    checkpoint = overlay_str e.checkpoint row.checkpoint;
    mode = overlay_str e.mode row.mode;
    result = overlay_str e.result row.result;
    at = overlay_str e.at row.at;
    reason = overlay_str e.reason row.reason;
    ended_ms = (if row.ended_ms > 0 then row.ended_ms else e.ended_ms);
  }

let json_str fields k =
  match List.assoc_opt k fields with Some (`String s) -> s | _ -> ""

let json_int fields k d =
  match List.assoc_opt k fields with
  | Some (`Int n) -> n
  | Some (`Float f) -> int_of_float f
  | _ -> d

let json_bool fields k d =
  match List.assoc_opt k fields with Some (`Bool b) -> b | _ -> d

let apply_run_json e fields =
  let s k cur = overlay_str cur (json_str fields k) in
  {
    e with
    kind = s "kind" e.kind;
    game = s "game" e.game;
    game_name = s "game_name" e.game_name;
    program = s "program" e.program;
    program_name = s "program_name" e.program_name;
    group = s "group" e.group;
    from = s "from" e.from;
    to_ = s "to" e.to_;
    checkpoint = s "checkpoint" e.checkpoint;
    backend = s "backend" e.backend;
    mode = s "mode" e.mode;
    result = s "result" e.result;
    at = s "at" e.at;
    reason = s "reason" e.reason;
    started_ms = json_int fields "started_ms" e.started_ms;
    ended_ms = json_int fields "ended_ms" e.ended_ms;
    recorded = e.recorded || json_bool fields "recorded" false;
  }

let read_json_assoc path =
  if not (Sys.file_exists path) then None
  else
    match Repo_io.Json_file.read path with
    | Ok (`Assoc fs) -> Some fs
    | _ -> None

let apply_daemon_json e dir =
  match read_json_assoc (Filename.concat dir "daemon.json") with
  | None -> e
  | Some fs ->
      let started = json_int fs "clock_zero_unix_ms" e.started_ms in
      {
        e with
        backend = fallback_str e.backend (json_str fs "backend");
        started_ms = (if e.started_ms > 0 then e.started_ms else started);
      }

let classify_summary text =
  if String.starts_with ~prefix:"PASS" text then "pass"
  else if String.starts_with ~prefix:"FAIL" text then "fail"
  else ""

let result_of_summary dir =
  let path = Filename.concat dir "summary.txt" in
  if Sys.file_exists path && not (Sys.is_directory path) then
    classify_summary (In_channel.with_open_text path In_channel.input_all)
  else ""

let has_recorded_frames dir =
  Sys.file_exists (Filename.concat (Filename.concat dir "frames") "index.jsonl")

let dir_mtime_ms dir =
  int_of_float ((Unix.stat dir).Unix.st_mtime *. float_of_int ms_per_sec)

let default_kind e =
  if e.kind <> "" then e.kind
  else if e.mode = "preflight" then "preflight"
  else if e.checkpoint = "" then "daemon"
  else "checkpoints"

let finalize_entry e =
  let e = enrich_program e in
  let from, to_ =
    if e.from <> "" then (e.from, e.to_) else (e.checkpoint, e.checkpoint)
  in
  {
    e with
    kind = default_kind e;
    result = fallback_str e.result "unknown";
    from;
    to_;
  }

let read_run_dir runs_dir tsv name =
  let dir = Filename.concat runs_dir name in
  let e = empty_entry name in
  let e =
    match Run_history_parse.parse_run_name name with
    | Some (checkpoint, mode) -> { e with checkpoint; mode }
    | None -> e
  in
  let e =
    Option.fold ~none:e ~some:(apply_tsv_row e) (Hashtbl.find_opt tsv name)
  in
  let e =
    if e.result = "" then { e with result = result_of_summary dir } else e
  in
  let e = apply_daemon_json e dir in
  let e =
    Option.fold ~none:e ~some:(apply_run_json e)
      (read_json_assoc (Filename.concat dir "run.json"))
  in
  let started_ms =
    if e.started_ms > 0 then e.started_ms else dir_mtime_ms dir
  in
  finalize_entry
    { e with started_ms; recorded = e.recorded || has_recorded_frames dir }

let take n xs =
  let rec go acc k = function
    | [] -> List.rev acc
    | _ when k <= 0 -> List.rev acc
    | x :: rest -> go (x :: acc) (k - 1) rest
  in
  go [] n xs

let compare_newest a b =
  let c = Int.compare b.started_ms a.started_ms in
  if c <> 0 then c else String.compare b.run a.run

let entry_of_tsv run row =
  let e = apply_tsv_row (empty_entry run) row in
  finalize_entry
    {
      e with
      started_ms = (if e.started_ms > 0 then e.started_ms else e.ended_ms);
    }

let parse_tsv ?(limit = default_limit) text =
  String.split_on_char '\n' text
  |> List.filter_map Run_history_parse.parse_tsv_line
  |> List.rev
  |> List.map (fun (run, row) -> entry_of_tsv run row)
  |> take limit

let read_tsv_file runs_dir =
  let path = Filename.concat runs_dir "RESULTS.tsv" in
  if Sys.file_exists path && not (Sys.is_directory path) then
    Run_history_parse.tsv_table
      (In_channel.with_open_text path In_channel.input_all)
  else Hashtbl.create 0

let scan_dir_entry runs_dir tsv seen name =
  let path = Filename.concat runs_dir name in
  if
    Run_history_parse.valid_run_name name
    && Sys.file_exists path && Sys.is_directory path
  then (
    Hashtbl.replace seen name ();
    Some (read_run_dir runs_dir tsv name))
  else None

let load ?(limit = default_limit) ~runs_dir () =
  if not (Sys.file_exists runs_dir && Sys.is_directory runs_dir) then []
  else
    let tsv = read_tsv_file runs_dir in
    let seen = Hashtbl.create initial_tbl_size in
    let dirs =
      Sys.readdir runs_dir |> Array.to_list
      |> List.filter_map (scan_dir_entry runs_dir tsv seen)
    in
    let add_tsv run row acc =
      if Hashtbl.mem seen run then acc else entry_of_tsv run row :: acc
    in
    List.sort compare_newest (dirs @ Hashtbl.fold add_tsv tsv []) |> take limit

let entry_to_json e =
  `Assoc
    [
      ("run", `String e.run);
      ("kind", `String e.kind);
      ("game", `String e.game);
      ("game_name", `String e.game_name);
      ("program", `String e.program);
      ("program_name", `String e.program_name);
      ("group", `String e.group);
      ("checkpoint", `String e.checkpoint);
      ("from", `String e.from);
      ("to", `String e.to_);
      ("backend", `String e.backend);
      ("mode", `String e.mode);
      ("result", `String e.result);
      ("at", `String e.at);
      ("reason", `String e.reason);
      ("started_ms", `Int e.started_ms);
      ("ended_ms", `Int e.ended_ms);
      ("recorded", `Bool e.recorded);
    ]

let to_json ~runs_dir entries =
  `Assoc
    [
      ("runs_dir", `String runs_dir);
      ("watch_hub_port", `Int watch_hub_port);
      ("entries", `List (List.map entry_to_json entries));
    ]
