(* Every plan in the repo as Plan_text prints it, for the golden test
   (plans.golden): the program plans under the directory given (the build
   tree's copy of src/games/frlg/programs) and PokemonSimulation's authored
   FireRed plans, each loaded as FireRed loads it (Frlg_checkpoints.Plan_file).
   A change that keeps plans.golden as it is reads every plan the same way. *)

let plan_files dir =
  Sys.readdir dir |> Array.to_list
  |> List.filter (fun name -> Filename.check_suffix name ".plan.json")
  |> List.sort compare

(* src/games/frlg/programs/<program>/plans/*.plan.json, as
   "<program>/plans/<file>". *)
let program_plans programs =
  Sys.readdir programs |> Array.to_list |> List.sort compare
  |> List.concat_map (fun program ->
      let plans = Filename.concat program "plans" in
      if Sys.file_exists (Filename.concat programs plans) then
        List.map (Filename.concat plans)
          (plan_files (Filename.concat programs plans))
      else [])
  |> List.map (fun name -> (name, Filename.concat programs name))

let authored_plans () =
  let relative = "third_party/PokemonSimulation/data/story/frlg-authored" in
  match Repo_io.Repo_files.locate relative with
  | None -> failwith (relative ^ " not found above the test dir")
  | Some dir ->
      List.map
        (fun name -> ("frlg-authored/" ^ name, Filename.concat dir name))
        (plan_files dir)

let plan_lines (plan : Checkpoints_plan.Plan.t) =
  List.concat
    [
      [ Plan_text.outline plan ];
      List.map Plan_text.event plan.checkpoint.events;
      [ Printf.sprintf "retries %d" plan.retries; "postconditions:" ];
      [ Plan_text.postconditions plan; Plan_text.repeat plan ];
    ]

let print (name, path) =
  print_endline ("== " ^ name);
  match Frlg_checkpoints.Plan_file.load path with
  | Ok plan -> List.iter print_endline (plan_lines plan)
  | Error message -> print_endline ("error: " ^ message)

let () =
  List.iter print (program_plans Sys.argv.(1));
  List.iter print (authored_plans ())
