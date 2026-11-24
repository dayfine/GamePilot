(* gamepilot checkpoints PLAN_DIR --from ID --to ID ... --make-room MAP

   Room in the party before the chain (Frlg_story.Make_room): back to the save
   (mGBA: mg-00's start state, else the first checkpoint's, kept as mg-00's;
   Switch: the soft reset), each member's summary read (species, level,
   moves), and the room policy's deposits for the chain from ID on
   (Frlg_story.Party_room). None needed: the chain runs as it is. Else the
   generated checkpoint mg-00 (Fly to the Center nearest MAP, the save's map,
   the deposit, out to the Fly landing) is written with the chain's plans
   (linked) into "<runs>/<ID>-make-room/plans", and the series runs from mg-00
   there: it is judged, retried and saved like any checkpoint. *)

module Pf = Preflight_command
module M = Frlg_story.Make_room
module R = Story.Room_policy

let ( let* ) = Result.bind

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

(* mGBA: mg-00 starts from its own state, else from the chain's first. *)
let ensure_start (setup : Pf.setup) from_id =
  let own = state setup M.id and first = state setup from_id in
  match setup.backend with
  | Daemon_process.Mgba _ when Sys.file_exists own -> Ok ()
  | Daemon_process.Mgba _ when Sys.file_exists first -> Ok (copy_file first own)
  | Daemon_process.Mgba _ -> Error ("no start state " ^ first)
  | Daemon_process.Switch _ -> Ok ()

exception Not_read

let read_party (setup : Pf.setup) log () =
  Pf.reload setup M.id log;
  match Frlg_story.Postcondition_reads.party_summary ~log with
  | Some members -> members
  | None -> raise Not_read

let read_live setup log port =
  match Live.run ~port (read_party setup log) with
  | members -> Ok members
  | exception Not_read -> Error "the party's summaries did not read"
  | exception Pf.Not_back e -> Error ("could not return to the save: " ^ e)
  | exception Effects.Disconnected e -> Error ("disconnected: " ^ e)

let party setup record log =
  match
    Daemon_process.start ~daemon:setup.Pf.daemon ~backend:setup.backend ~port:0
      ~wire_log:(Run_record.path record "wire.jsonl")
      ~out_file:(Run_record.path record "daemon.out")
      ~checkpoint:M.id ()
  with
  | Error e -> Error ("daemon: " ^ e)
  | Ok d ->
      Fun.protect
        ~finally:(fun () -> Daemon_process.stop d)
        (fun () -> read_live setup log d.port)

let knows_fly (m : R.member) =
  Option.fold ~none:false ~some:(List.mem "fly") m.moves

let room ~at need members =
  let* towns = Frlg_actions.Fly_towns.load () in
  let* dir =
    Option.to_result ~none:"no maps"
      (Frlg_repo_files.Repo_files.locate Frlg_story.Checkpoint_run.maps_dir)
  in
  let maps = Grid_maps.Map_file.runtime_names ~maps_dir:dir in
  let* center = M.nearest_center towns ~maps at in
  let* deposits =
    R.choose
      (Frlg_story.Party_room.rules need)
      (Frlg_story.Party_room.precondition need)
      members
  in
  let* fly_user =
    Option.to_result ~none:"no member knows Fly"
      (List.find_opt knows_fly members)
  in
  Ok
    ( deposits,
      {
        M.center;
        fly_user = fly_user.species;
        deposits;
        party = members;
        needed_moves =
          List.sort_uniq compare ("fly" :: need.Frlg_story.Party_room.moves);
      } )

(* The chain's plans linked beside mg-00's. *)
let write_plans ~plan_dir dir room =
  Sys.mkdir dir 0o755;
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
    (M.plan_json room);
  Ok ()

let prepare ~plan_dir ~from_id ~at (setup : Pf.setup) =
  let* plans = chain_plans ~plan_dir from_id in
  let need = Frlg_story.Party_room.chain_need plans in
  let* () = ensure_start setup from_id in
  let record =
    Run_record.create ~runs_dir:setup.runs_dir ~checkpoint:from_id
      ~mode:"make-room"
  in
  let log, close = Run_record.story_log record in
  let members = party setup record log in
  close ();
  let* members = members in
  List.iter
    (fun m -> print_endline ("[Make room] " ^ R.member_to_string m))
    members;
  let* deposits, room = room ~at need members in
  print_endline ("[Make room] " ^ R.plan_to_string deposits);
  if deposits = [] then Ok None
  else
    let dir = Filename.concat record.dir "plans" in
    let* () = write_plans ~plan_dir dir room in
    print_endline
      ("[Make room] " ^ M.id ^ ": Fly to " ^ room.center.name ^ ", in " ^ dir);
    Ok (Some dir)

(* --make-room: mg-00 first when the party needs room, from its plan dir. *)
let with_room ~plan_dir ~from_id make_room setup =
  match make_room with
  | None -> Ok (plan_dir, from_id)
  | Some at -> (
      let* dir = prepare ~plan_dir ~from_id ~at setup in
      match dir with
      | None -> Ok (plan_dir, from_id)
      | Some dir -> Ok (dir, M.id))
