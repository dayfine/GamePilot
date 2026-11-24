(* gamepilot checkpoints PLAN_DIR --preflight --from ID [--backend ...]

   The pre-flight of a save (Frlg_story.Preflight): back to the last save (on
   the Switch the soft reset; on mGBA the checkpoint's start state), then the
   party, money and bag items the first checkpoint's plan needs and the place
   (against the start frame kept there), read with the existing readers and
   printed as a table. Exit 1 on a mismatch or a need not read. Its daemon's
   wire log and the story log go to a run folder ("<ID>-preflight"). *)

open Story
module Pf = Frlg_story.Preflight
module C = Frlg_story.Start_check

type setup = {
  states : string;
  runs_dir : string;
  daemon : string;
  backend : Daemon_process.backend;
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
  | None -> { p with party = Some (Story.Plan.Party_includes []) }

let session setup id (needs, room) log () =
  reload setup id log;
  let place = place setup id log in
  let observed =
    Frlg_story.Postcondition_reads.observe ~log (with_party (Pf.to_read needs))
  in
  let read = { Pf.observed; place } in
  Pf.compare needs read @ [ Pf.room room read ]

let report id rows =
  print_endline (Pf.table rows);
  let ok = Pf.passed rows in
  Printf.printf "[Preflight] %s: %s\n%!" id
    (if ok then "the save holds what it needs" else "MISMATCH: not starting");
  if ok then 0 else 1

let stopped id why =
  Printf.printf "[Preflight] %s: %s\n%!" id why;
  1

let with_daemon setup record id body =
  match
    Daemon_process.start ~daemon:setup.daemon ~backend:setup.backend ~port:0
      ~wire_log:(Run_record.path record "wire.jsonl")
      ~out_file:(Run_record.path record "daemon.out")
      ~checkpoint:id ()
  with
  | Error e -> stopped id ("daemon: " ^ e)
  | Ok daemon ->
      Fun.protect
        ~finally:(fun () -> Daemon_process.stop daemon)
        (fun () -> body daemon)

let in_daemon setup id needs log (d : Daemon_process.t) =
  match Live.run ~port:d.port (session setup id needs log) with
  | rows -> report id rows
  | exception Not_back e -> stopped id ("could not return to the save: " ^ e)
  | exception Effects.Disconnected e -> stopped id ("disconnected: " ^ e)

let run ~plan_dir ~from_id setup =
  let* needs = needs ~plan_dir from_id in
  let record =
    Run_record.create ~runs_dir:setup.runs_dir ~checkpoint:from_id
      ~mode:"preflight"
  in
  let log, close = Run_record.story_log record in
  print_endline ("[Preflight] " ^ record.dir);
  let result =
    with_daemon setup record from_id (in_daemon setup from_id needs log)
  in
  close ();
  Ok result
