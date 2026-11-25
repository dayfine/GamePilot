(* A level grind as a scripted world: each run of the checkpoint's battle batch
   raises the lead's level by [per_batch]; a save keeps the level and a reload
   goes back to the saved one. Batches and saves fail where the script says.
   Logs the world's lines and the loop's, not the runner's per-event ones. *)

open Pokemon_engine

type script = {
  start_level : int;
  per_batch : int;
  failing_batches : (int * Failure.cause) list;
      (* Batch number (from 1, counting retries) -> how it fails, after one
         level of progress the reload will lose. *)
  failing_save : int option; (* The save (from 1) that fails. *)
}

let script =
  { start_level = 1; per_batch = 3; failing_batches = []; failing_save = None }

let checkpoint =
  Plan_files.checkpoint_of_events
    [
      {|{"id": "to_grass", "kind": "route", "args": {"target": {"map": "Route", "tiles": [[3, 3]]}}}|};
      {|{"id": "battles", "kind": "game_action", "action": "battle_batch", "args": {"battles": 10}}|};
      {|{"id": "to_center", "kind": "route", "args": {"target": {"map": "Center", "tiles": [[7, 4]]}}}|};
    ]

let make script =
  let level = ref script.start_level and saved = ref script.start_level in
  let batches = ref 0 and saves = ref 0 and lines = ref [] in
  let log line =
    if not (String.starts_with ~prefix:"[Story]" line) then
      lines := line :: !lines
  in
  let batch _event _args =
    incr batches;
    let before = !level in
    match List.assoc_opt !batches script.failing_batches with
    | Some cause ->
        level := before + 1;
        log
          (Printf.sprintf "batch %d: level %d -> %d, then failed" !batches
             before !level);
        Error cause
    | None ->
        level := before + script.per_batch;
        log (Printf.sprintf "batch %d: level %d -> %d" !batches before !level);
        Ok ()
  in
  let save () =
    incr saves;
    if Some !saves = script.failing_save then
      Error (Failure.cause "save_not_confirmed" "no saved text")
    else (
      saved := !level;
      log (Printf.sprintf "save at level %d" !level);
      Ok ())
  in
  let reload () =
    log (Printf.sprintf "reload: level %d -> %d" !level !saved);
    level := !saved;
    Ok ()
  in
  let game : Game.t =
    {
      run_own = (fun _ _ -> Ok ());
      run_builtin = (fun _ -> Ok ());
      game_actions = [ ("battle_batch", batch) ];
      flag_holds = (fun _ -> false);
      position = (fun () -> None);
      between_rounds = (fun () -> Ok ());
      save;
      reload;
      log;
    }
  in
  let reached target () = Ok (!level >= target) in
  (game, reached, fun () -> String.concat "\n" (List.rev !lines))
