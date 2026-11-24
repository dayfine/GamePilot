(* What one checkpoint run leaves on disk, under the runs folder
   ($GAMEPILOT_RUNS, else ~/.local/share/gamepilot/runs):

     <date>-<checkpoint>-<mode>-<n>/
       wire.jsonl    the daemon's wire log (replays with gamepilot replay)
       daemon.out    the daemon's own output
       story.log     the story lines, a verdict per event and the end check
       failure.png   the frame at the failure; failure.ss its save state
       end.ss        a passing run's end (verification only)
       summary.txt   one line: PASS, or FAIL with the step and the reason
       KEEP          on a failing run, so the disk GC keeps it (replay-test
                     candidate)
       run.json      what the hub's runs list shows (the program's game, id,
                     name and group from the registry, the series' range,
                     checkpoint, backend, mode, start), written at the start
                     and again with the result at the end
       daemon.json, watch_plan.json, watch_run.json, watch_log.jsonl,
       frames/       the daemon's notes and recorded frames
                     (daemon/src/run_journal.h, frame_stream.h)
     RESULTS.tsv     one row per run, across all runs

   The C++ writes its failure screenshot to Screenshots/AutoStory/failures
   (InterruptLogGuard::save_frame() in
   PokemonFRLG/Programs/AutoStory/PokemonFRLG_AutoStoryStepInterrupts.cpp,
   fork frlg/lean); run records there are written by hand
   (pokemon_sv/lab/runs/*/RESULT.md on the agents branch). Here the runner
   writes them. *)

type t = { dir : string; name : string }

let date () =
  let tm = Unix.localtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02d" (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday

let time () =
  let tm = Unix.localtime (Unix.time ()) in
  Printf.sprintf "%sT%02d:%02d:%02d" (date ()) tm.tm_hour tm.tm_min tm.tm_sec

let rec make_dirs dir =
  if not (Sys.file_exists dir) then (
    make_dirs (Filename.dirname dir);
    Sys.mkdir dir 0o755)

(* The first free <date>-<checkpoint>-<mode>-<n>. *)
let create ~runs_dir ~checkpoint ~mode =
  make_dirs runs_dir;
  let rec free n =
    let name = Printf.sprintf "%s-%s-%s-%d" (date ()) checkpoint mode n in
    let dir = Filename.concat runs_dir name in
    if Sys.file_exists dir then free (n + 1)
    else (
      Sys.mkdir dir 0o755;
      { dir; name })
  in
  free 1

let path t file = Filename.concat t.dir file

let write t file text =
  Out_channel.with_open_bin (path t file) (fun out ->
      Out_channel.output_string out text)

(* A logger to stdout and story.log; closed by the returned function. *)
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

(* One row in RESULTS.tsv next to the run folders. *)
let append_result ~runs_dir t ~checkpoint ~mode ~result ~at ~reason =
  let file = Filename.concat runs_dir "RESULTS.tsv" in
  let row = results_row t ~checkpoint ~mode ~result ~at ~reason in
  let text = if Sys.file_exists file then row else results_header ^ row in
  let flags = [ Open_wronly; Open_creat; Open_append; Open_binary ] in
  Out_channel.with_open_gen flags 0o644 file (fun out ->
      Out_channel.output_string out text)

let copy_file ~src ~dst =
  let bytes = In_channel.with_open_bin src In_channel.input_all in
  Out_channel.with_open_bin dst (fun out -> Out_channel.output_string out bytes)

type info = {
  program : Program_registry.t option;
      (** None: a plan folder of no program. *)
  from_id : string;
  to_id : string;
  backend : string;
}
(** What run.json says of a run besides its outcome: the program it belongs to
    and the series it is part of. *)

type ending = { result : string; at : string; reason : string }

let now_ms () = int_of_float (Unix.gettimeofday () *. 1000.)

(* The program's run.json fields; empty game and program for none. *)
let program_fields = function
  | Some p -> Program_registry.run_fields p
  | None -> [ ("game", ""); ("program", "") ]

let run_json t info ~checkpoint ~mode ~started_ms ending =
  let s v = `String v in
  let program =
    List.map (fun (k, v) -> (k, s v)) (program_fields info.program)
  in
  let ended =
    match ending with
    | None -> []
    | Some e ->
        [
          ("ended_ms", `Int (now_ms ()));
          ("result", s e.result);
          ("at", s e.at);
          ("reason", s e.reason);
        ]
  in
  `Assoc
    ((("run", s t.name) :: program)
    @ [
        ("from", s info.from_id);
        ("to", s info.to_id);
        ("checkpoint", s checkpoint);
        ("backend", s info.backend);
        ("mode", s mode);
        ("started_ms", `Int started_ms);
      ]
    @ ended)

(* run.json, at the start ([ending] None) and again at the end. *)
let write_run_json t info ~checkpoint ~mode ~started_ms ending =
  write t "run.json"
    (Yojson.Safe.to_string
       (run_json t info ~checkpoint ~mode ~started_ms ending)
    ^ "\n")
