(* Plan files outside the dune project (third_party/, the program plans), found
   from the build dir, and plans written inline. *)

let repo_path relative =
  let rec up dir =
    let candidate = Filename.concat dir relative in
    if Sys.file_exists candidate then candidate
    else
      let parent = Filename.dirname dir in
      if parent = dir then failwith (relative ^ " not found above the test dir")
      else up parent
  in
  up (Sys.getcwd ())

let plans_in dir =
  Sys.readdir dir |> Array.to_list
  |> List.filter (fun name -> Filename.check_suffix name ".plan.json")
  |> List.sort compare
  |> List.map (Filename.concat dir)

let authored_dir =
  repo_path "third_party/PokemonSimulation/data/story/frlg-authored"

let mail_glitch_dir = repo_path "src/games/frlg/programs/mail_glitch/plans"

(* A plan with these events, decoded as a plan file would be. *)
let checkpoint_of_events events =
  let text =
    Printf.sprintf
      {|{"format": "gamepilot-checkpoint/1", "game": "test", "execution": {},
         "checkpoint": {"id": "cp", "title": "test", "events": [%s]}}|}
      (String.concat ", " events)
  in
  match
    Pokemon_engine.Plan_decode.decode ~source:"inline"
      (Yojson.Safe.from_string text)
  with
  | Ok plan -> plan.checkpoint
  | Error message -> failwith message
