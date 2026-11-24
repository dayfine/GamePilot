(* gamepilot runs --backfill [--apply] [--runs-dir DIR]

   A run.json for each run folder from before every run path wrote one
   (Run_record), so the hub's runs list shows its kind, program, start and
   end. Three kinds of folder get one:

   - a series' run (<date>-<checkpoint>-<testing|verification>-<n>, else
     story.log's "[Run] <checkpoint> run <n>" line): kind checkpoints;
   - a pre-flight (<date>-<checkpoint>-preflight-<n>): kind preflight, its
     result from story.log's "[Preflight] <checkpoint>: ..." verdict line;
   - a daemon started by hand (no checkpoint, but daemon.json, daemon.out or
     wire.jsonl: the Switch's idle and bring-up daemons): kind daemon, its
     label the name after the date.

   The program is the registry's with a plan for the checkpoint
   (Program_registry.of_checkpoint); a checkpoint of no registered program (a
   scratch plan's) is left out. The start is daemon.json's clock_zero_unix_ms,
   else the wire log's span back from its last write, else the folder's mtime;
   the end is the wire log's last line. The backend is daemon.json's, else
   daemon.out's first line.

   A dry run by default: it prints what it would write. --apply writes. Only
   run.json is ever written, and only in a folder that has none and whose
   daemon is not live. Run it from the repo: the plans are found from the
   working directory up. *)

module R = Program_registry

type kind = Checkpoints | Preflight | Daemon

type found = {
  run : string;
  kind : kind;
  checkpoint : string;  (** For a daemon: its label. *)
  mode : string option;
  program : R.t option;
}

let kind_name = function
  | Checkpoints -> "checkpoints"
  | Preflight -> "preflight"
  | Daemon -> "daemon"

let read_text path =
  match In_channel.with_open_bin path In_channel.input_all with
  | text -> Some text
  | exception Sys_error _ -> None

let lines dir file =
  Option.fold ~none:[]
    ~some:(String.split_on_char '\n')
    (read_text (Filename.concat dir file))

(* The first word after [prefix] on the first line that has it, and the
   rest. *)
let after_prefix prefix lines =
  List.find_map
    (fun line ->
      if String.starts_with ~prefix line then
        let n = String.length prefix in
        Some (String.sub line n (String.length line - n))
      else None)
    lines

(* The checkpoint of story.log's first "[Run] <checkpoint> run <n>" line. *)
let of_story_log dir =
  match after_prefix "[Run] " (lines dir "story.log") with
  | Some rest -> (
      match String.split_on_char ' ' rest with
      | checkpoint :: "run" :: _ -> Some checkpoint
      | _ -> None)
  | None -> None

let date_length = String.length "2026-11-23-"
let daemon_files = [ "daemon.json"; "daemon.out"; "wire.jsonl" ]

let daemon_label dir name =
  if List.exists (fun f -> Sys.file_exists (Filename.concat dir f)) daemon_files
  then
    Some
      (if String.length name > date_length then
         String.sub name date_length (String.length name - date_length)
       else name)
  else None

(* A folder whose name gives no checkpoint: story.log's, else a daemon's. *)
let unnamed dir run =
  match (of_story_log dir, daemon_label dir run) with
  | Some c, _ -> Some (Checkpoints, c)
  | None, Some label -> Some (Daemon, label)
  | None, None -> None

let find runs_dir run =
  let dir = Filename.concat runs_dir run in
  let kind, mode =
    match Run_record.parse_name run with
    | Some (c, "preflight") -> (Some (Preflight, c), Some "preflight")
    | Some (c, (("testing" | "verification") as m)) ->
        (Some (Checkpoints, c), Some m)
    | _ -> (unnamed dir run, None)
  in
  Option.map
    (fun (kind, checkpoint) ->
      let program =
        if kind = Daemon then None else R.of_checkpoint checkpoint
      in
      { run; kind; checkpoint; mode; program })
    kind

(* A run folder with no run.json yet. *)
let candidate runs_dir name =
  let dir = Filename.concat runs_dir name in
  name.[0] <> '.'
  && Sys.is_directory dir
  && not (Sys.file_exists (Filename.concat dir "run.json"))

let candidates runs_dir =
  Sys.readdir runs_dir |> Array.to_list |> List.sort compare
  |> List.filter (candidate runs_dir)

let classify = function
  | _, Some ({ kind = Daemon; _ } as f) -> Either.Left f
  | _, Some ({ program = Some _; _ } as f) -> Left f
  | n, Some f -> Right (n ^ " (" ^ f.checkpoint ^ ": no program)")
  | n, None -> Right (n ^ " (no checkpoint)")

let fields f =
  let s v = `String v in
  let program =
    Option.fold ~none:[] ~some:R.run_fields f.program
    |> List.map (fun (k, v) -> (k, s v))
  in
  (("run", s f.run) :: ("kind", s (kind_name f.kind)) :: program)
  @ [ ("checkpoint", s f.checkpoint) ]
  @ match f.mode with Some m -> [ ("mode", s m) ] | None -> []

let run_json runs_dir f =
  let dir = Filename.concat runs_dir f.run in
  let verdict =
    if f.kind = Preflight then
      Run_record.Folder_facts.preflight_verdict f.checkpoint
        (lines dir "story.log")
    else []
  in
  `Assoc
    (fields f
    @ Run_record.Folder_facts.of_folder dir
    @ verdict
    @ [ ("backfilled", `Bool true) ])

let write runs_dir f =
  let file = Filename.concat (Filename.concat runs_dir f.run) "run.json" in
  Out_channel.with_open_bin file (fun out ->
      Out_channel.output_string out
        (Yojson.Safe.to_string (run_json runs_dir f) ^ "\n"))

let describe f =
  match f.program with
  | Some p -> Printf.sprintf "%s %s %s" (kind_name f.kind) p.id f.checkpoint
  | None -> Printf.sprintf "%s %s" (kind_name f.kind) f.checkpoint

let report ~apply runs_dir (known, unknown) =
  let verb = if apply then "wrote" else "would write" in
  List.iter
    (fun f ->
      if apply then write runs_dir f;
      Printf.printf "%s %s/run.json: %s\n" verb f.run (describe f))
    known;
  List.iter (fun u -> print_endline ("left out " ^ u)) unknown;
  Printf.printf "%s %d run.json, left out %d folder(s)%s\n" verb
    (List.length known) (List.length unknown)
    (if apply then "" else "; --apply writes them")

let main ~apply ~live runs_dir =
  match candidates runs_dir with
  | exception Sys_error e -> Error e
  | names ->
      List.filter (fun n -> not (List.mem n live)) names
      |> List.map (fun n -> (n, find runs_dir n))
      |> List.partition_map classify
      |> report ~apply runs_dir;
      Ok 0
