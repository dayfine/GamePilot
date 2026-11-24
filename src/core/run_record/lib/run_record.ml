(* What a run leaves on disk, under the runs folder ($GAMEPILOT_RUNS, else
   ~/.local/share/gamepilot/runs). Every run path writes its folder through
   [start] and [finish]: a checkpoint series' runs (gamepilot checkpoints), the
   pre-flight, one checkpoint (gamepilot checkpoint), a one-shot program
   (gamepilot run) and the Switch's bring-up checks (gamepilot bring-up). A
   daemon started by hand with --run-folder writes a run.json of its own
   (daemon/src/run_journal.h, kind "daemon").

     <date>-<label>-<mode>-<n>/
       run.json      what the hub's runs list shows: the kind of run, the
                     program's game, id, name and group from the registry, the
                     series' range, checkpoint, backend, mode, start; written
                     at the start and again with the result at the end
       summary.txt   PASS, or FAIL with the step and the reason (the
                     pre-flight: its table, then the verdict)
       KEEP          on a failing run, so the disk GC keeps it
       failure.png   the frame at the failure (failure.ss its save state, mGBA)
       story.log, wire.jsonl, daemon.out, end.ss, daemon.json, frames/, ...
     RESULTS.tsv     one row per finished run, across all runs

   The C++ writes its failure screenshot to Screenshots/AutoStory/failures
   (InterruptLogGuard::save_frame() in
   PokemonFRLG/Programs/AutoStory/PokemonFRLG_AutoStoryStepInterrupts.cpp,
   fork frlg/lean); run records there are written by hand
   (pokemon_sv/lab/runs/*/RESULT.md on the agents branch). Here the runner
   writes them. *)

type t = { dir : string; name : string }

let year_zero = 1900
let dir_perm = 0o755
let file_perm = 0o644
let ms_per_s = 1000.

let date () =
  let tm = Unix.localtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02d" (tm.tm_year + year_zero) (tm.tm_mon + 1)
    tm.tm_mday

let time () =
  let tm = Unix.localtime (Unix.time ()) in
  Printf.sprintf "%sT%02d:%02d:%02d" (date ()) tm.tm_hour tm.tm_min tm.tm_sec

let rec make_dirs dir =
  if not (Sys.file_exists dir) then (
    make_dirs (Filename.dirname dir);
    Sys.mkdir dir dir_perm)

(* The first free <date>-<label>-<mode>-<n>. *)
let create ~runs_dir ~checkpoint ~mode =
  make_dirs runs_dir;
  let rec free n =
    let name = Printf.sprintf "%s-%s-%s-%d" (date ()) checkpoint mode n in
    let dir = Filename.concat runs_dir name in
    if Sys.file_exists dir then free (n + 1)
    else (
      Sys.mkdir dir dir_perm;
      { dir; name })
  in
  free 1

let path t file = Filename.concat t.dir file

let append t file text =
  Out_channel.with_open_gen
    [ Open_wronly; Open_creat; Open_append; Open_binary ]
    file_perm (path t file) (fun out -> Out_channel.output_string out text)

let write t file text =
  Out_channel.with_open_bin (path t file) (fun out ->
      Out_channel.output_string out text)

let story_log t =
  let out = open_out (path t "story.log") in
  let log line =
    print_endline line;
    output_string out (line ^ "\n");
    flush out
  in
  (log, fun () -> close_out out)

let results_header = "time\trun\tcheckpoint\tmode\tresult\tat\treason\n"

let results_row t ~checkpoint ~mode ~result ~at ~reason =
  let clean s = String.map (function '\t' | '\n' -> ' ' | c -> c) s in
  String.concat "\t"
    (List.map clean [ time (); t.name; checkpoint; mode; result; at; reason ])
  ^ "\n"

let append_result ~runs_dir t ~checkpoint ~mode ~result ~at ~reason =
  let file = Filename.concat runs_dir "RESULTS.tsv" in
  let row = results_row t ~checkpoint ~mode ~result ~at ~reason in
  let text = if Sys.file_exists file then row else results_header ^ row in
  let flags = [ Open_wronly; Open_creat; Open_append; Open_binary ] in
  Out_channel.with_open_gen flags file_perm file (fun out ->
      Out_channel.output_string out text)

let copy_file ~src ~dst =
  let bytes = In_channel.with_open_bin src In_channel.input_all in
  Out_channel.with_open_bin dst (fun out -> Out_channel.output_string out bytes)

type kind = Checkpoints | Checkpoint | Program | Preflight | Bring_up

let kind_name = function
  | Checkpoints -> "checkpoints"
  | Checkpoint -> "checkpoint"
  | Program -> "program"
  | Preflight -> "preflight"
  | Bring_up -> "bring-up"

(* The modes a run folder's name may end in, before its number. *)
let modes =
  [ "testing"; "verification"; "preflight"; "single"; "run"; "bring-up" ]

let date_length = String.length "2026-11-23"
let is_number s = s <> "" && String.for_all (fun c -> c >= '0' && c <= '9') s

let is_date s =
  String.length s = date_length
  && String.for_all (fun c -> (c >= '0' && c <= '9') || c = '-') s

(* [rest] less "-<mode>" for the first mode it ends in. *)
let split_mode rest =
  List.find_map
    (fun mode ->
      let n = String.length rest - String.length mode - 1 in
      if n > 0 && String.ends_with ~suffix:("-" ^ mode) rest then
        Some (String.sub rest 0 n, mode)
      else None)
    modes

(* "<date>-<label>-<mode>-<n>": the label and the mode. *)
let parse_name name =
  let n = String.length name in
  let after_date = date_length + 1 in
  match String.rindex_opt name '-' with
  | Some last
    when last > after_date
         && name.[date_length] = '-'
         && is_date (String.sub name 0 date_length)
         && is_number (String.sub name (last + 1) (n - last - 1)) ->
      split_mode (String.sub name after_date (last - after_date))
  | _ -> None

type info = {
  kind : kind;
  program : (string * string) list;
  from_id : string;
  to_id : string;
  backend : string;
}

type ending = { result : string; at : string; reason : string }

let now_ms () = int_of_float (Unix.gettimeofday () *. ms_per_s)

type run = {
  record : t;
  info : info;
  checkpoint : string;
  mode : string;
  started_ms : int;
  attempt : (int * int) option;
}

let program_fields = function
  | [] -> [ ("game", ""); ("program", "") ]
  | fields -> fields

let ended_fields ~ended_ms = function
  | None -> []
  | Some e ->
      [
        ("ended_ms", `Int ended_ms);
        ("result", `String e.result);
        ("at", `String e.at);
        ("reason", `String e.reason);
      ]

let attempt_fields = function
  | None -> []
  | Some (n, of_) -> [ ("attempt", `Int n); ("attempts", `Int of_) ]

let run_json run ~ended_ms ending =
  let s v = `String v in
  let info = run.info in
  let program =
    List.map (fun (k, v) -> (k, s v)) (program_fields info.program)
  in
  `Assoc
    ((("run", s run.record.name) :: ("kind", s (kind_name info.kind)) :: program)
    @ [
        ("from", s info.from_id);
        ("to", s info.to_id);
        ("checkpoint", s run.checkpoint);
        ("backend", s info.backend);
        ("mode", s run.mode);
        ("started_ms", `Int run.started_ms);
      ]
    @ attempt_fields run.attempt
    @ ended_fields ~ended_ms ending)

let write_run_json run ending =
  write run.record "run.json"
    (Yojson.Safe.to_string (run_json run ~ended_ms:(now_ms ()) ending) ^ "\n")

let start ?attempt ~runs_dir info ~checkpoint ~mode =
  let record = create ~runs_dir ~checkpoint ~mode in
  let run =
    { record; info; checkpoint; mode; started_ms = now_ms (); attempt }
  in
  write_run_json run None;
  run

let finish ~runs_dir run ~summary ending =
  write run.record "summary.txt" (summary ^ "\n");
  if ending.result = "fail" then write run.record "KEEP" "a failing run\n";
  write_run_json run (Some ending);
  append_result ~runs_dir run.record ~checkpoint:run.checkpoint ~mode:run.mode
    ~result:ending.result ~at:ending.at ~reason:ending.reason

type save = Frame | State

let failure_saves ~save_states =
  ("failure.png", Frame)
  :: (if save_states then [ ("failure.ss", State) ] else [])

module Folder_facts = Folder_facts
