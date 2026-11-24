(* gamepilot runs --backfill [--apply] [--runs-dir DIR]

   A run.json for each run folder from before run.json carried the program
   (Run_record), so the hub's runs list shows and filters its game and program.
   The checkpoint comes from the folder's name (<date>-<checkpoint>-<mode>-<n>),
   else from story.log's "[Run] <checkpoint> run <n>" line; the program is the
   registry's with a plan for that checkpoint (Program_registry.of_checkpoint).
   The run logs name no plan folder, so a checkpoint of no registered program
   (a scratch plan's) stays unknown and its folder is left as it is.

   A dry run by default: it prints what it would write. --apply writes. Only
   run.json is ever written, and only in a folder that has none and whose
   daemon is not live (its runner writes its own). Run it from the repo: the
   plans are found from the working directory up. *)

module R = Program_registry

type found = {
  run : string;
  checkpoint : string;
  mode : string option;
  program : R.t option;
}

let date_length = String.length "2026-11-23"
let modes = [ "testing"; "verification" ]
let is_number s = s <> "" && String.for_all (fun c -> c >= '0' && c <= '9') s

(* <date>-<checkpoint>-<mode>-<n>: the checkpoint and the mode. *)
let of_name name =
  let parts = String.split_on_char '-' name in
  let n = List.length parts in
  let part i = if i >= 0 && i < n then List.nth parts i else "" in
  let mode = part (n - 2) in
  let dated = String.length name > date_length && n >= 6 in
  if dated && List.mem mode modes && is_number (part (n - 1)) then
    let checkpoint = List.filteri (fun i _ -> i >= 3 && i < n - 2) parts in
    Some (String.concat "-" checkpoint, mode)
  else None

let run_prefix = "[Run] "

(* The checkpoint of story.log's first "[Run] <checkpoint> run <n>" line. *)
let of_story_log dir =
  match
    In_channel.with_open_bin
      (Filename.concat dir "story.log")
      In_channel.input_lines
  with
  | exception Sys_error _ -> None
  | lines -> (
      match List.find_opt (String.starts_with ~prefix:run_prefix) lines with
      | None -> None
      | Some line -> (
          match String.split_on_char ' ' line with
          | _ :: checkpoint :: "run" :: _ -> Some checkpoint
          | _ -> None))

let find runs_dir run =
  let dir = Filename.concat runs_dir run in
  let checkpoint, mode =
    match of_name run with
    | Some (c, m) -> (Some c, Some m)
    | None -> (of_story_log dir, None)
  in
  Option.map
    (fun checkpoint ->
      { run; checkpoint; mode; program = R.of_checkpoint checkpoint })
    checkpoint

let run_json f p =
  let s v = `String v in
  `Assoc
    ((("run", s f.run) :: List.map (fun (k, v) -> (k, s v)) (R.run_fields p))
    @ [ ("checkpoint", s f.checkpoint) ]
    @ (match f.mode with Some m -> [ ("mode", s m) ] | None -> [])
    @ [ ("backfilled", `Bool true) ])

(* A run folder with no run.json yet. *)
let candidate runs_dir name =
  let dir = Filename.concat runs_dir name in
  name.[0] <> '.'
  && Sys.is_directory dir
  && not (Sys.file_exists (Filename.concat dir "run.json"))

let candidates runs_dir =
  Sys.readdir runs_dir |> Array.to_list |> List.sort compare
  |> List.filter (candidate runs_dir)

let write runs_dir f p =
  let file = Filename.concat (Filename.concat runs_dir f.run) "run.json" in
  Out_channel.with_open_bin file (fun out ->
      Out_channel.output_string out (Yojson.Safe.to_string (run_json f p) ^ "\n"))

let classify = function
  | _, Some ({ program = Some p; _ } as f) -> Either.Left (f, p)
  | n, Some f -> Right (n ^ " (" ^ f.checkpoint ^ ": no program)")
  | n, None -> Right (n ^ " (no checkpoint)")

let report ~apply runs_dir (known, unknown) =
  let verb = if apply then "wrote" else "would write" in
  List.iter
    (fun (f, (p : R.t)) ->
      if apply then write runs_dir f p;
      Printf.printf "%s %s/run.json: %s %s\n" verb f.run p.id f.checkpoint)
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
