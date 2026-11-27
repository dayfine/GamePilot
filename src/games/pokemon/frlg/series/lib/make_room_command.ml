(* gamepilot run PROGRAM|DIR/PLANS --from ID --to ID ... --make-room MAP

   Room in the party before the chain (Frlg_checkpoints.Make_room): back to the save
   (mGBA: 00-make-room's start state, else the first checkpoint's, kept as 00-make-room's;
   Switch: the soft reset), each member's summary read (species, level,
   moves), and the room policy's deposits for the chain from ID on
   (Frlg_checkpoints.Party_room). None needed: the chain runs as it is. Else the
   generated checkpoint 00-make-room (Fly to the Center nearest MAP, the save's map,
   the deposit, out to the Fly landing) is written with the chain's plans
   (linked) into "<runs>/<ID>-make-room/plans", and the series runs from 00-make-room
   there: it is judged, retried and saved like any checkpoint. The party read
   runs as a shadow plan (Frlg_checkpoints.Shadow_plan: soft_reset, read_party,
   plan_deposit), so the watch page shows it as a checkpoint run. *)

module Pf = Preflight_command
module M = Frlg_checkpoints.Make_room
module R = Room_policy
module Pr = Frlg_checkpoints.Party_room
module Cr = Frlg_checkpoints.Checkpoint_run

let ( let* ) = Result.bind

(* rwxr-xr-x: 00-make-room's plan folder. *)
let dir_perm = 0o755

let chain_plans ~plan_dir from_id =
  let* ids = Plan_dir.checkpoint_ids plan_dir in
  List.fold_left
    (fun acc id ->
      let* acc = acc in
      let* p = Plan_dir.load_plan ~plan_dir id in
      Ok (acc @ [ p ]))
    (Ok [])
    (Plan_dir.drop_until from_id ids)

let state (setup : Pf.setup) id = Filename.concat setup.states (id ^ ".start.ss")

let copy_file from to_ =
  let bytes = In_channel.with_open_bin from In_channel.input_all in
  Out_channel.with_open_bin to_ (fun oc -> Out_channel.output_string oc bytes)

(* mGBA: 00-make-room starts from its own state, else from the chain's first. *)
let ensure_start (setup : Pf.setup) from_id =
  let own = state setup M.id and first = state setup from_id in
  match setup.backend with
  | Daemon_process.Mgba _ when Sys.file_exists own -> Ok ()
  | Daemon_process.Mgba _ when Sys.file_exists first -> Ok (copy_file first own)
  | Daemon_process.Mgba _ -> Error ("no start state " ^ first)
  | Daemon_process.Switch _ -> Ok ()

let knows_fly (m : R.member) =
  Option.fold ~none:false ~some:(List.mem "fly") m.moves

let room ~at need members =
  let* towns = Frlg_actions.Fly_towns.load () in
  let* places = Frlg_places.Place_table.load () in
  let* world = Cr.load_world () in
  let* center = M.nearest_center towns ~places ~maps:world.maps at in
  let* deposits = R.choose (Pr.rules need) (Pr.precondition need) members in
  let* () =
    if List.exists knows_fly members then Ok () else Error "no member knows Fly"
  in
  Ok
    ( deposits,
      {
        M.center;
        deposits;
        party = members;
        needed_moves = List.sort_uniq compare ("fly" :: need.Pr.moves);
      } )

(* The chain's plans linked beside 00-make-room's. *)
let write_plans ~plan_dir dir room =
  Sys.mkdir dir dir_perm;
  let* ids = Plan_dir.checkpoint_ids plan_dir in
  List.iter
    (fun id ->
      let file = id ^ Plan_dir.plan_suffix in
      Unix.symlink
        (Filename.concat (Unix.realpath plan_dir) file)
        (Filename.concat dir file))
    ids;
  Yojson.Safe.to_file
    (Filename.concat dir (M.id ^ Plan_dir.plan_suffix))
    (M.room_plan room);
  Ok ()

let say lines line =
  print_endline ("[Make room] " ^ line);
  lines := line :: !lines

(* The party read, the policy's pick and 00-make-room's plans in [record]. *)
let decide ~plan_dir ~at need (record : Run_record.t) say members =
  List.iter (fun m -> say (R.member_to_string m)) members;
  let* deposits, room = room ~at need members in
  say (R.plan_to_string deposits);
  if deposits = [] then Ok None
  else
    let dir = Filename.concat record.dir "plans" in
    let* () = write_plans ~plan_dir dir room in
    say (M.id ^ ": Fly to " ^ room.center.town.name ^ ", in " ^ dir);
    Ok (Some dir)

let action f : Pokemon_engine.Game.game_action = fun _ _ -> f ()

let failed code why =
  Error (Pokemon_engine.Failure.cause ~repeats:true code why)

let soft_reset setup result log () =
  match Pf.reload setup M.id log with
  | () -> Ok ()
  | exception Pf.Not_back e ->
      result := Error ("could not return to the save: " ^ e);
      failed "not_back" e

let read_members members result log () =
  match Frlg_checkpoints.Postcondition_reads.party_summary ~log with
  | Some read ->
      members := read;
      Ok ()
  | None ->
      result := Error "the party's summaries did not read";
      failed "not_read" "the party's summaries did not read"

let plan_deposit decide members result say log () =
  let both line =
    say line;
    log line
  in
  result := decide both !members;
  Result.fold ~ok:(fun _ -> Ok ()) ~error:(failed "no_room") !result

(* The shadow plan's steps (Frlg_checkpoints.Shadow_plan.make_room_steps); the
   party read and the decision in [result]. *)
let actions (setup : Pf.setup) decide result say log =
  let members = ref [] in
  [
    ("soft_reset", action (soft_reset setup result log));
    ("read_party", action (read_members members result log));
    ("plan_deposit", action (plan_deposit decide members result say log));
  ]

let shadow_plan =
  Frlg_checkpoints.Shadow_plan.plan ~id:M.id ~title:"make room: the party read"
    Frlg_checkpoints.Shadow_plan.make_room_steps

(* In the session: the shadow plan through the checkpoint runner, on the
   page. *)
let session setup world decide say log () =
  let result = ref (Error "the party read did not finish") in
  (match
     Frlg_checkpoints.Plan_watch.run_shadow ~mode:"preflight" ~log world
       shadow_plan
       (actions setup decide result say)
   with
  | Ok () -> ()
  | Error f when Result.is_ok !result ->
      result := Error (Pokemon_engine.Failure.to_string f)
  | Error _ -> ());
  !result

let read_live setup world decide say log port =
  match Live.run ~port (session setup world decide say log) with
  | result -> result
  | exception Effects.Disconnected e -> Error ("disconnected: " ^ e)

let party setup world record decide say log =
  match
    Daemon_process.start ?watch:setup.Pf.watch
      ~flags:(Daemon_process.viewport_args setup.backend setup.viewport)
      ~daemon:setup.daemon ~backend:setup.backend ~port:0
      ~wire_log:(Run_record.path record "wire.jsonl")
      ~out_file:(Run_record.path record "daemon.out")
      ~checkpoint:M.id ()
  with
  | Error e -> Error ("daemon: " ^ e)
  | Ok d ->
      Fun.protect
        ~finally:(fun () -> Daemon_process.stop d)
        (fun () -> read_live setup world decide say log d.port)

let ending = function
  | Ok _ -> Run_record.{ result = "pass"; at = ""; reason = "" }
  | Error why -> { result = "fail"; at = "make-room"; reason = why }

(* A pre-flight run of 00-make-room's own ("<date>-00-make-room-preflight-<n>"). *)
let prepare ~plan_dir ~from_id ~at (setup : Pf.setup) =
  let* plans = chain_plans ~plan_dir from_id in
  let* need = Pr.chain_need plans in
  let* () = ensure_start setup from_id in
  let* world = Frlg_checkpoints.Checkpoint_run.load_world () in
  let* run =
    Run_record.start ~runs_dir:setup.runs_dir setup.info ~checkpoint:M.id
      ~mode:"preflight"
  in
  let log, close = Run_record.run_log run.record in
  let lines = ref [] in
  let result =
    party setup world run.record
      (decide ~plan_dir ~at need run.record)
      (say lines) log
  in
  close ();
  Result.iter_error (say lines) result;
  let summary = String.concat "\n" (List.rev !lines) in
  Run_record.finish ~runs_dir:setup.runs_dir run ~summary (ending result);
  result

(* --make-room: 00-make-room first when the party needs room, from its plan dir. *)
let with_room ~plan_dir ~from_id make_room setup =
  match make_room with
  | None -> Ok (plan_dir, from_id)
  | Some at -> (
      let* dir = prepare ~plan_dir ~from_id ~at setup in
      match dir with
      | None -> Ok (plan_dir, from_id)
      | Some dir -> Ok (dir, M.id))
