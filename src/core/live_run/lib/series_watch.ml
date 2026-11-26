(* A checkpoint series' record (Series_record) where the hub reads it,
   [<registry>/series/<id>.json], rewritten whole at each change; nothing
   without a watch page. *)

type watched = { registry : string; mutable record : Series_record.t }
type t = watched option

(* rw-r--r--: the record. *)
let file_perm = 0o644

let file ~registry id =
  Filename.concat (Filename.concat registry "series") (id ^ ".json")

(* Written aside, then renamed: the hub never reads half of it. *)
let write w =
  let path = file ~registry:w.registry (Series_record.id w.record) in
  Run_record.make_dirs (Filename.dirname path);
  let aside = path ^ ".new" in
  Out_channel.with_open_gen [ Open_wronly; Open_creat; Open_trunc; Open_binary ]
    file_perm aside (fun out ->
      Yojson.Safe.to_channel out (Series_record.to_json w.record);
      Out_channel.output_char out '\n');
  Sys.rename aside path

let update t f =
  Option.iter
    (fun w ->
      w.record <- f w.record;
      write w)
    t

(* "<date>-<from>-<to>-<pid>": one series per runner. *)
let series_id (info : Run_record.info) pid =
  Printf.sprintf "%s-%s-%s-%d" (Run_record.date ()) info.from_id info.to_id pid

let started (watch : Daemon_process.watch) info ~mode ids =
  let pid = Unix.getpid () in
  let record =
    Series_record.create ~id:(series_id info pid) ~pid info ~mode
      ~started_ms:(Run_record.now_ms ()) ids
  in
  let w = { registry = watch.registry; record } in
  write w;
  w

let start watch info ~mode ids =
  Option.map (fun w -> started w info ~mode ids) watch

let id t = Option.map (fun w -> Series_record.id w.record) t
let run_started t run ~n = update t (fun r -> Series_record.begin_run r run ~n)

let run_ended t run ending =
  update t (fun r ->
      Series_record.end_run r run ending ~now_ms:(Run_record.now_ms ()))

let finished t ~passed =
  update t (fun r ->
      Series_record.finish r ~passed ~now_ms:(Run_record.now_ms ()))
