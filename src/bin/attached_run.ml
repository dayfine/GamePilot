(* A run on a daemon that is already up (gamepilot checkpoint, gamepilot run
   <program>): a run folder of its own in --runs-dir ($GAMEPILOT_RUNS) through
   Run_record, so the hub lists it like a series' run. The wire log stays
   with the daemon. *)

let default_runs_dir () =
  match Sys.getenv_opt "GAMEPILOT_RUNS" with
  | Some dir when dir <> "" -> dir
  | _ ->
      List.fold_left Filename.concat
        (Option.value (Sys.getenv_opt "HOME") ~default:".")
        [ ".local"; "share"; "gamepilot"; "runs" ]

(* --runs-dir DIR out of [args], wherever it is; else the default. *)
let runs_dir_flag args =
  let rec go dir kept = function
    | [] -> Ok (dir, List.rev kept)
    | [ "--runs-dir" ] -> Error "--runs-dir needs a folder"
    | "--runs-dir" :: d :: rest -> go d kept rest
    | a :: rest -> go dir (a :: kept) rest
  in
  go (default_runs_dir ()) [] args

(* run.json's program fields; none for no program. *)
let program_fields = Option.fold ~none:[] ~some:Program_registry.run_fields

let start ~runs_dir ~kind ~program ~label ~mode =
  let info : Run_record.info =
    {
      kind;
      program = program_fields program;
      from_id = label;
      to_id = label;
      backend = "";
    }
  in
  Result.map
    (fun (run : Run_record.run) ->
      print_endline ("[Run] " ^ run.record.dir);
      run)
    (Run_record.start ~runs_dir info ~checkpoint:label ~mode)

(* The frame now, in the session; a refusal (an older daemon) is skipped. *)
let save_failure (record : Run_record.t) =
  match Effects.save_frame (Run_record.path record "failure.png") with
  | (_ : int) -> ()
  | exception Effects.Rpc_error _ -> ()

let finish ~runs_dir run ~line ~code =
  let ending : Run_record.ending =
    if code = 0 then { result = "pass"; at = ""; reason = "" }
    else { result = "fail"; at = ""; reason = line }
  in
  Run_record.finish ~runs_dir run ~summary:line ending
