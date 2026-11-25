(* gamepilot checkpoints PLAN_DIR --preflight --from ID [--backend ...]

   The pre-flight of a save (Frlg_checkpoints.Preflight): back to the last save (on
   the Switch the soft reset; on mGBA the checkpoint's start state), then the
   party, money, bag items and badges the first checkpoint's plan needs and the
   place (against the start frame kept there), read with the existing readers and
   printed as a table. Exit 1 on a mismatch or a need not read. Its daemon's
   wire log and the story log go to a run folder ("<ID>-preflight"), with
   run.json (mode preflight), the table and the verdict in summary.txt, the
   RESULTS.tsv row and, on a mismatch or a failed reload, failure.png
   (Run_record). It runs as a shadow plan (Frlg_checkpoints.Shadow_plan: soft_reset,
   check_start, read_party, read_trainer_card, verdict) through the checkpoint
   runner, so with --watch its daemon's page shows its steps, story lines and
   run as a checkpoint run's (Frlg_checkpoints.Plan_watch). *)

open Pokemon_checkpoints
module Pf = Frlg_checkpoints.Preflight
module C = Frlg_checkpoints.Start_check

type setup = {
  states : string;
  runs_dir : string;
  daemon : string;
  backend : Daemon_process.backend;
  viewport : string option;
      (** The Switch daemon's --viewport: the program's
          (Program_registry.check_viewport). *)
  info : Run_record.info;
  watch : Daemon_process.watch option;
}

let ( let* ) = Result.bind

let needs ~plan_dir from_id =
  let* plan = Plan_dir.load_plan ~plan_dir from_id in
  let* before = Plan_dir.promised_before ~plan_dir from_id in
  let* stocks = Frlg_actions.Mart_plan.load () in
  let* ids = Plan_dir.checkpoint_ids plan_dir in
  let chain = Plan_dir.drop_until from_id ids in
  let* plans =
    List.fold_left
      (fun acc id ->
        let* acc = acc in
        let* p = Plan_dir.load_plan ~plan_dir id in
        Ok (acc @ [ p ]))
      (Ok []) chain
  in
  match
    (Pf.needs stocks ~before plan, Frlg_checkpoints.Party_room.chain_need plans)
  with
  | needs, room -> Result.map (fun needs -> (needs, room)) needs
  | exception Json_field.Invalid e -> Error e

exception Not_back of string

(* Back to what the save holds. *)
let reload setup id log =
  match setup.backend with
  | Daemon_process.Mgba _ ->
      let path = Filename.concat setup.states (id ^ ".start.ss") in
      if Sys.file_exists path then ignore (Effects.load_state path)
      else raise (Not_back ("no start state " ^ path))
  | Switch _ -> (
      match Frlg_actions.Soft_reset.return_to_save ~log () with
      | Ok () -> ()
      | Error c -> raise (Not_back (Failure.cause_to_string c)))

let load_kept log path =
  match C.load_frame path with
  | Ok frame -> frame
  | Error e ->
      log ("[Preflight] " ^ e);
      None

(* The frame kept under the id, else the one kept at the plan's start (a
   renamed or split checkpoint's). *)
let kept setup id start log =
  match load_kept log (C.frame_file ~states:setup.states id) with
  | Some frame -> Some frame
  | None ->
      Option.bind (C.start_file ~states:setup.states start) (load_kept log)

let place setup id start log =
  let frame = C.read_frame () in
  match kept setup id start log with
  | Some reference ->
      Option.map (Frlg_readers.Start_frame.compare ~reference) frame
  | None -> None

(* The party is read on its summaries (species, level, moves): the room and
   the field moves are judged on them. *)
let without_party (p : Pokemon_checkpoints.Postconditions.t) =
  { p with party = None }

let party_of (members : Checkpoints_run.Room_policy.member list) =
  List.map
    (fun (m : Checkpoints_run.Room_policy.member) ->
      if m.species = "?" then None else Some m.species)
    members

(* The frame where the pre-flight stopped; a refusal is logged, not fatal. *)
let save_failure record log =
  match Effects.save_frame (Run_record.path record "failure.png") with
  | (_ : int) -> log "[Preflight] saved failure.png"
  | exception Effects.Rpc_error e ->
      log ("[Preflight] could not save failure.png: " ^ e.message)

type verdict = Rows of Pf.row list | Stopped of string

type reads = {
  mutable place : Frlg_readers.Start_frame.difference option;
  mutable members : Checkpoints_run.Room_policy.member list option;
  mutable observed : Pokemon_checkpoints.Postcondition_check.observed option;
  mutable card : Frlg_readers.Trainer_card_front.t option;
  mutable verdict : verdict;
}

let action f : Pokemon_checkpoints.Game.game_action = fun _ _ -> f ()

(* Back to the save: on a failure, its frame and the verdict. *)
let soft_reset setup record id reads log () =
  match reload setup id log with
  | () -> Ok ()
  | exception Not_back e ->
      save_failure record log;
      reads.verdict <- Stopped ("could not return to the save: " ^ e);
      Error (Failure.cause ~repeats:true "not_back" e)

(* The table of what was read; a mismatch fails the step. *)
let judge record (needs, room) reads log () =
  let read =
    {
      Pf.observed =
        (match reads.observed with
        | Some o -> { o with party = Option.map party_of reads.members }
        | None -> invalid_arg "verdict before read_trainer_card");
      place = reads.place;
      members = reads.members;
      card = reads.card;
    }
  in
  let rows = Pf.compare needs read @ [ Pf.room room read ] in
  reads.verdict <- Rows rows;
  if Pf.passed rows then Ok ()
  else (
    save_failure record log;
    Error (Failure.cause "mismatch" "the save does not hold what it needs"))

let check_start setup id start reads log () =
  reads.place <- place setup id start log;
  Ok ()

let read_party reads log () =
  reads.members <- Frlg_checkpoints.Postcondition_reads.party_summary ~log;
  Ok ()

let read_trainer_card needs reads log () =
  reads.observed <-
    Some
      (Frlg_checkpoints.Postcondition_reads.observe ~log
         (without_party (Pf.to_read needs)));
  if Pf.reads_card needs then
    reads.card <- Frlg_checkpoints.Postcondition_reads.trainer_card ~log;
  Ok ()

(* The shadow plan's steps (Frlg_checkpoints.Shadow_plan.preflight_steps). The
   party is read on its summaries (species, level, moves): the room and the
   field moves are judged on them. *)
let actions setup record id start ((needs, _) as all) reads log =
  [
    ("soft_reset", action (soft_reset setup record id reads log));
    ("check_start", action (check_start setup id start reads log));
    ("read_party", action (read_party reads log));
    ("read_trainer_card", action (read_trainer_card needs reads log));
    ("verdict", action (judge record all reads log));
  ]

let shadow_plan id =
  Frlg_checkpoints.Shadow_plan.plan ~id ~title:("pre-flight of " ^ id)
    Frlg_checkpoints.Shadow_plan.preflight_steps

(* The pre-flight as a plan through the checkpoint runner, on the page. *)
let session setup record id start needs world log () =
  let reads =
    {
      place = None;
      members = None;
      observed = None;
      card = None;
      verdict = Stopped "";
    }
  in
  match
    Frlg_checkpoints.Plan_watch.run_shadow ~mode:"preflight" ~log world
      (shadow_plan id)
      (actions setup record id start needs reads)
  with
  | Ok () -> reads.verdict
  | Error f -> (
      match reads.verdict with
      | Stopped "" -> Stopped (Failure.to_string f)
      | v -> v)

(* The table (none when nothing was read), the verdict line, the result. *)
let ending_of id = function
  | Rows rows when Pf.passed rows ->
      ( Some (Pf.table rows),
        id ^ ": the save holds what it needs",
        Run_record.{ result = "pass"; at = ""; reason = "" } )
  | Rows rows ->
      ( Some (Pf.table rows),
        id ^ ": MISMATCH: not starting",
        { result = "fail"; at = "preflight"; reason = "mismatch" } )
  | Stopped why ->
      ( None,
        id ^ ": " ^ why,
        { result = "fail"; at = "preflight"; reason = why } )

let with_daemon setup record id body =
  match
    Daemon_process.start ?watch:setup.watch
      ~flags:(Daemon_process.viewport_args setup.backend setup.viewport)
      ~daemon:setup.daemon ~backend:setup.backend ~port:0
      ~wire_log:(Run_record.path record "wire.jsonl")
      ~out_file:(Run_record.path record "daemon.out")
      ~checkpoint:id ()
  with
  | Error e -> Stopped ("daemon: " ^ e)
  | Ok daemon ->
      Fun.protect
        ~finally:(fun () -> Daemon_process.stop daemon)
        (fun () -> body daemon)

let in_daemon setup record id start needs world log (d : Daemon_process.t) =
  match
    Live.run ~port:d.port (session setup record id start needs world log)
  with
  | verdict -> verdict
  | exception Effects.Disconnected e -> Stopped ("disconnected: " ^ e)

let run ~plan_dir ~from_id setup =
  let* needs = needs ~plan_dir from_id in
  let* plan = Plan_dir.load_plan ~plan_dir from_id in
  let start = plan.checkpoint.start in
  let* world = Frlg_checkpoints.Checkpoint_run.load_world () in
  let run =
    Run_record.start ~runs_dir:setup.runs_dir setup.info ~checkpoint:from_id
      ~mode:"preflight"
  in
  let record = run.record in
  let log, close = Run_record.story_log record in
  print_endline ("[Preflight] " ^ record.dir);
  let verdict =
    with_daemon setup record from_id
      (in_daemon setup record from_id start needs world log)
  in
  let table, line, ending = ending_of from_id verdict in
  Option.iter print_endline table;
  Printf.printf "[Preflight] %s\n%!" line;
  close ();
  let summary =
    String.concat "\n" (Option.to_list table @ [ "PREFLIGHT " ^ line ])
  in
  Run_record.finish ~runs_dir:setup.runs_dir run ~summary ending;
  Ok (if ending.result = "pass" then 0 else 1)
