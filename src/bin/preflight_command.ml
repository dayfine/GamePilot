(* gamepilot checkpoints PLAN_DIR --preflight --from ID [--backend ...]

   The pre-flight of a save (Frlg_story.Preflight): back to the last save (on
   the Switch the soft reset; on mGBA the checkpoint's start state), then the
   party, money and bag items the first checkpoint's plan needs and the place
   (against the start frame kept there), read with the existing readers and
   printed as a table. Exit 1 on a mismatch or a need not read. Its daemon's
   wire log and the story log go to a run folder ("<ID>-preflight"), with
   run.json (mode preflight), the table and the verdict in summary.txt, the
   RESULTS.tsv row and, on a mismatch or a failed reload, failure.png
   (Run_record). With --watch its daemon's page is in the watch registry while
   it runs, as a checkpoint run's. *)

open Story
module Pf = Frlg_story.Preflight
module C = Frlg_story.Start_check

type setup = {
  states : string;
  runs_dir : string;
  daemon : string;
  backend : Daemon_process.backend;
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
    (Pf.needs stocks ~before plan, Frlg_story.Party_room.chain_need plans)
  with
  | needs, room -> Ok (needs, room)
  | exception Grid_maps.Json_field.Invalid e -> Error e

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

let place setup id log =
  let frame = C.read_frame () in
  match C.load_frame (C.frame_file ~states:setup.states id) with
  | Ok (Some reference) ->
      Option.map (Frlg_readers.Start_frame.compare ~reference) frame
  | Ok None -> None
  | Error e ->
      log ("[Preflight] " ^ e);
      None

(* The party is always read: the chain's room needs it. *)
let with_party (p : Story.Plan.postconditions) =
  match p.party with
  | Some _ -> p
  | None ->
      {
        p with
        party = Some (Story.Plan.Party_includes { members = []; slots = [] });
      }

(* The frame where the pre-flight stopped; a refusal is logged, not fatal. *)
let save_failure record log =
  match Effects.save_frame (Run_record.path record "failure.png") with
  | (_ : int) -> log "[Preflight] saved failure.png"
  | exception Effects.Rpc_error e ->
      log ("[Preflight] could not save failure.png: " ^ e.message)

type verdict = Rows of Pf.row list | Stopped of string

let session setup record id (needs, room) log () =
  match reload setup id log with
  | exception Not_back e ->
      save_failure record log;
      Stopped ("could not return to the save: " ^ e)
  | () ->
      let place = place setup id log in
      let observed =
        Frlg_story.Postcondition_reads.observe ~log
          (with_party (Pf.to_read needs))
      in
      let read = { Pf.observed; place } in
      let rows = Pf.compare needs read @ [ Pf.room room read ] in
      if not (Pf.passed rows) then save_failure record log;
      Rows rows

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
    Daemon_process.start ?watch:setup.watch ~daemon:setup.daemon
      ~backend:setup.backend ~port:0
      ~wire_log:(Run_record.path record "wire.jsonl")
      ~out_file:(Run_record.path record "daemon.out")
      ~checkpoint:id ()
  with
  | Error e -> Stopped ("daemon: " ^ e)
  | Ok daemon ->
      Fun.protect
        ~finally:(fun () -> Daemon_process.stop daemon)
        (fun () -> body daemon)

let in_daemon setup record id needs log (d : Daemon_process.t) =
  match Live.run ~port:d.port (session setup record id needs log) with
  | verdict -> verdict
  | exception Effects.Disconnected e -> Stopped ("disconnected: " ^ e)

let run ~plan_dir ~from_id setup =
  let* needs = needs ~plan_dir from_id in
  let run =
    Run_record.start ~runs_dir:setup.runs_dir setup.info ~checkpoint:from_id
      ~mode:"preflight"
  in
  let record = run.record in
  let log, close = Run_record.story_log record in
  print_endline ("[Preflight] " ^ record.dir);
  let verdict =
    with_daemon setup record from_id (in_daemon setup record from_id needs log)
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
