(* The checkpoint runner's steps on a console without save states (the
   Switch), around each run, as Checkpoints_series.Console_runs decides them: back to the
   last save (Frlg_actions.Soft_reset) and the start check
   (Frlg_checkpoints.Start_check) before; after, the in-game save and the next
   start's frame for a pass (Frlg_actions.Game_save), back to the last save for
   a failure. In the effect context. *)

open Pokemon_engine
open Checkpoints_series
module C = Frlg_checkpoints.Start_check

let log_results log results =
  List.iter
    (fun r -> log ("[Start] " ^ Postcondition_check.result_to_string r))
    results

(* The party a checkpoint starts with: the one the checkpoint before it
   promised, else the roster given with --party. *)
let start_party ~roster (before : Postconditions.t option) =
  match (before, roster) with
  | Some { party = Some p; _ }, _ -> Some p
  | _, [] -> None
  | _, roster -> Some (Postconditions.Party_in_order roster)

let cause = Failure.cause_to_string

let load_frame ~log path =
  match C.load_frame path with
  | Ok frame -> frame
  | Error e ->
      log ("[Start] " ^ e);
      None

(* The frame kept under the checkpoint's id, else the one kept at its start;
   none for a checkpoint that starts anywhere (no [frame_path]). *)
let kept_frame ~log ~frame_path ~start_path =
  match (Option.bind frame_path (load_frame ~log), start_path) with
  | Some frame, _ -> Some frame
  | None, Some path ->
      let frame = load_frame ~log path in
      if Option.is_some frame then
        log "[Start] no frame kept for this id; the one kept at its start";
      frame
  | None, None -> None

(* Keeps the frame read as the file's when the file has none. *)
let keep_missing ~log frame path =
  if not (Sys.file_exists path) then C.write_frame ~log path frame

let keep_all ~log ~frame_path ~start_path frame =
  List.iter (keep_missing ~log frame)
    (Option.to_list frame_path @ Option.to_list start_path)

(* After the reload: the frame first kept as the start's (by id and by start)
   when none was. *)
let start_check ~log ~frame_path ~start_path party =
  let expected = { C.party; frame = kept_frame ~log ~frame_path ~start_path } in
  let observed = C.observe ~log expected in
  let results = C.check expected observed in
  log_results log results;
  match C.mismatches results with
  | [] ->
      Option.iter (keep_all ~log ~frame_path ~start_path) observed.frame_read;
      Ok ()
  | l -> Error ("not at the checkpoint's start: " ^ String.concat "; " l)

let ( let* ) = Result.bind

let reset_to_save ~log =
  log "[Console] back to the last save";
  Result.map_error
    (fun c -> "could not return to the last save: " ^ cause c)
    (Frlg_actions.Soft_reset.return_to_save ~log ())

let before_step ~log = function
  | Console_runs.Return_to_save -> reset_to_save ~log
  | Save_in_game | Keep_start_frame -> Ok ()

let before ~log ~picture ~home_tile ~frame_path ~start_path ~steps party =
  let already_at_start = not (List.mem Console_runs.Return_to_save steps) in
  let* () =
    Switch.Initial_screen.check_unless_chained ~already_at_start ~log ~picture
      (In_game_or_resume home_tile)
  in
  let* () =
    List.fold_left
      (fun done_ s ->
        let* () = done_ in
        before_step ~log s)
      (Ok ()) steps
  in
  start_check ~log ~frame_path ~start_path party

let return_to_save ~log =
  match Frlg_actions.Soft_reset.return_to_save ~log () with
  | Ok () -> log "[Console] back at the last save"
  | Error c -> log ("[Console] could not return to the last save: " ^ cause c)

let step ~log ~next_frame = function
  | Console_runs.Return_to_save -> Ok (return_to_save ~log)
  | Keep_start_frame -> Ok (Option.iter (C.keep_frame ~log) next_frame)
  | Save_in_game ->
      Result.map_error
        (fun c -> "the in-game save failed: " ^ cause c)
        (Frlg_actions.Game_save.save_game ~log ())

(* Runs the steps; [Error] when the save failed (no step after it runs). *)
let after ~log ~next_frame steps =
  List.fold_left
    (fun done_ s ->
      Result.bind done_ (fun () ->
          log ("[Console] " ^ Console_runs.step_name s);
          step ~log ~next_frame s))
    (Ok ()) steps
