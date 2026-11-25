(* gamepilot run --plan PLAN.json [--state FILE] [--port N] [--log FILE]
     [--party SPECIES,...] [--center TOWN] [--walk] [--end-check-only]
     [--grind-battles N]
   gamepilot replay checkpoint WIRELOG PLAN.json [the same flags]

   Runs one checkpoint of a FireRed plan through the story runner. The state
   is loaded first and again on a reload; --party states the party at the
   checkpoint's start; without it the party is read from the members'
   summaries before the first action that finds a member by its species. With --end-check-only
   no event runs: the state is checked against the plan's postconditions.
   --grind-battles N (testing) ends each grind, passing, after N battles and
   skips the plan's moves postconditions (Frlg_checkpoints.Checkpoint_run).

   A live run gets a run folder in --runs-dir ($GAMEPILOT_RUNS) with
   run.json (kind checkpoint, mode single), story.log, summary.txt, the
   RESULTS.tsv row and failure.png on a failure (Attached_run); the wire log
   is the daemon's own. *)

let ( let* ) = Result.bind

type flags = Pokemon_flags.checkpoint_flags = {
  state : string option;
  port : int;
  log_file : string option;
  party : string;
  center : string option;
  walk : bool;
  end_check_only : bool;
  grind_cap : int option;
}

let usage =
  "  gamepilot run --plan PLAN.json [--state FILE] [--port N] [--log FILE] \
   [--runs-dir DIR]\n\
  \      [--party SPECIES,...] [--center TOWN] [--walk] [--end-check-only]\n\
  \      [--grind-battles N]\n\
  \  gamepilot replay checkpoint WIRELOG PLAN.json [same flags]\n"

let defaults = Pokemon_flags.checkpoint_defaults

let rec parse flags = function
  | [] -> Ok flags
  | "--state" :: s :: rest -> parse { flags with state = Some s } rest
  | "--port" :: p :: rest -> (
      match int_of_string_opt p with
      | Some port -> parse { flags with port } rest
      | None -> Error ("bad --port " ^ p))
  | "--log" :: f :: rest -> parse { flags with log_file = Some f } rest
  | "--party" :: p :: rest -> parse { flags with party = p } rest
  | "--center" :: t :: rest -> parse { flags with center = Some t } rest
  | "--walk" :: rest -> parse { flags with walk = true } rest
  | "--end-check-only" :: rest ->
      parse { flags with end_check_only = true } rest
  | "--grind-battles" :: n :: rest -> (
      match int_of_string_opt n with
      | Some cap when cap > 0 -> parse { flags with grind_cap = Some cap } rest
      | _ -> Error ("bad --grind-battles " ^ n))
  | a :: _ -> Error ("unknown argument " ^ a)

(* Every story line to stdout and, with --log, to the file. *)
let logger = function
  | None -> print_endline
  | Some path ->
      let out = open_out path in
      at_exit (fun () -> close_out out);
      fun line ->
        print_endline line;
        output_string out (line ^ "\n");
        flush out

let options flags : Frlg_checkpoints.Checkpoint_run.options =
  {
    state = flags.state;
    party =
      (if flags.party = "" then None
       else Some (Frlg_actions.Party_roster.of_string flags.party));
    center = flags.center;
    grind_cap = flags.grind_cap;
    gait = (if flags.walk then Walking else Running);
    end_check_only = flags.end_check_only;
    log = logger flags.log_file;
  }

let prepare plan_file flags =
  let* plan = Frlg_checkpoints.Plan_file.load plan_file in
  let* () = Frlg_checkpoints.Checkpoint_run.check_plan plan in
  let* world = Frlg_checkpoints.Checkpoint_run.load_world () in
  Ok (plan, world, options flags)

(* The outcome's line and exit code. *)
let report = function
  | Ok () -> ("checkpoint: PASSED", 0)
  | Error failure ->
      ("checkpoint: FAILED " ^ Pokemon_engine.Failure.to_string failure, 1)

(* The checkpoint under [handle], its failures from the handler reported. *)
let outcome handle run =
  match handle run with
  | result -> report result
  | exception Replay.Divergence e -> ("checkpoint: DIVERGED " ^ e, 1)
  | exception Effects.Disconnected e -> ("checkpoint: DISCONNECTED " ^ e, 1)
  | exception Effects.Stop_requested reason ->
      ("checkpoint: STOPPED " ^ reason, 1)
  | exception Unix.Unix_error (e, f, _) ->
      ( Printf.sprintf "checkpoint: CONNECT FAILED %s: %s" f
          (Unix.error_message e),
        1 )

(* Runs the checkpoint under [handle], [after] its result in the session;
   the outcome's line (printed) and exit code. *)
let run_with ?(after = ignore) handle plan_file flags =
  match prepare plan_file flags with
  | Error e -> ("checkpoint: " ^ e, 2)
  | Ok (plan, world, options) ->
      let body () =
        let result =
          Frlg_checkpoints.Plan_watch.run ~mode:"single" options world plan
        in
        after result;
        result
      in
      let line, code = outcome handle body in
      print_endline line;
      (line, code)

let label plan_file =
  let base = Filename.basename plan_file in
  Option.value
    (Filename.chop_suffix_opt ~suffix:".plan.json" base)
    ~default:(Filename.remove_extension base)

(* On the daemon at --port, in a run folder of its own (Attached_run): its
   story log unless --log names another. [program_fields]: run.json's program
   fields for a plan folder. *)
let live ~program_fields plan_file args =
  let* runs_dir, args = Attached_run.runs_dir_flag args in
  let* flags = parse defaults args in
  let id = label plan_file in
  let run =
    Attached_run.start ~runs_dir ~kind:Checkpoint
      ~program:(program_fields (Filename.dirname plan_file))
      ~label:id ~mode:"single" ()
  in
  let log_file =
    Some
      (Option.value flags.log_file
         ~default:(Run_record.path run.record "story.log"))
  in
  let after = function
    | Ok () -> ()
    | Error _ -> Attached_run.save_failure run.record
  in
  let line, code =
    Effects.with_run_folder run.record.dir (fun () ->
        run_with ~after
          (Live.run ~port:flags.port)
          plan_file { flags with log_file })
  in
  Attached_run.finish ~runs_dir run ~line ~code;
  Ok code

let replay wirelog plan_file args =
  Result.map
    (fun flags ->
      snd (run_with (Replay.run (Replay.log_of_file wirelog)) plan_file flags))
    (parse defaults args)
