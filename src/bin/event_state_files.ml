(* The save states an mGBA run keeps at each event's start, on disk
   (Pokemon_checkpoints.Event_states): saved through the daemon beside what the run read at
   the checkpoint's start, one per event (the newest run's), and found again
   for a partial run (--from-event). *)

open Pokemon_checkpoints
module Run = Frlg_checkpoints.Checkpoint_run

let write_reads path reads =
  Out_channel.with_open_bin (Event_states.kept_path path) (fun out ->
      Out_channel.output_string out
        (Yojson.Safe.to_string (Saved.to_json reads) ^ "\n"))

(* The older states of event [index] under another id. *)
let prune dir ~index ~keep =
  Sys.readdir dir |> Array.to_list
  |> List.filter (Event_states.is_other_state ~index ~keep)
  |> List.iter (fun name -> Sys.remove (Filename.concat dir name))

(* Saved to a temporary file, then moved: a state cut short never replaces a
   good one. A save the daemon refuses is logged, not fatal. *)
let keep ~states ~checkpoint ~log : Run.keep_event_state =
 fun ~index event reads ->
  let dir = Event_states.dir ~states ~checkpoint in
  let path = Event_states.path ~states ~checkpoint ~index ~event_id:event.id in
  let tmp = path ^ ".tmp" in
  Run_record.make_dirs dir;
  match Effects.save_state tmp with
  | (_ : int) ->
      Sys.rename tmp path;
      write_reads path reads;
      prune dir ~index ~keep:(Filename.basename path);
      log
        ("[Run] kept the state at "
        ^ Event_states.file ~index ~event_id:event.id)
  | exception Effects.Rpc_error e ->
      log
        (Printf.sprintf "[Run] could not keep the state at %s: %s" event.id
           e.message)

let read_kept ~missing path =
  let file = Event_states.kept_path path in
  if not (Sys.file_exists file) then Error missing
  else
    match Yojson.Safe.from_file file with
    | json -> Saved.of_json json
    | exception Yojson.Json_error e -> Error (file ^ ": " ^ e)

(* The kept state of [from_event]'s first event and the partial run from it. *)
let partial ~states ~checkpoint (plan : Plan.checkpoint) (from_event, to_event)
    =
  let ( let* ) = Result.bind in
  let ids = List.map (fun (e : Plan.event) -> e.id) plan.events in
  let* range = Engine_run.Event_range.resolve ids ~from_event ~to_event in
  let first = range.first in
  let event : Plan.event = List.nth plan.events first in
  let path =
    Event_states.path ~states ~checkpoint ~index:first ~event_id:event.id
  in
  let label = Engine_run.Event_range.label ids first in
  let missing = Event_states.missing ~checkpoint ~label ~path in
  if not (Sys.file_exists path) then Error missing
  else
    let* kept = read_kept ~missing path in
    Ok (path, { Run.range; kept })
