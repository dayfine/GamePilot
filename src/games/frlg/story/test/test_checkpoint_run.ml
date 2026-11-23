(* The Mail Glitch plans mg-01..mg-03 against FireRed's story game: each is a
   FireRed plan it runs, from its start tile, and the game actions it names
   that FireRed has no handler for yet (the runner refuses such a plan before
   its first event). *)

open Frlg_story

let plan file = Result.get_ok (Story.Plan_decode.load file)
let handled = "fly" :: Frlg_actions.Action_requests.names

let missing (p : Story.Plan.t) =
  List.filter_map
    (fun (e : Story.Plan.event) ->
      match (e.kind, e.action) with
      | Game_action _, Some name when not (List.mem name handled) -> Some name
      | _ -> None)
    p.checkpoint.events
  |> List.sort_uniq compare

let summary file () =
  let p = plan file in
  let checked =
    match Checkpoint_run.check_plan p with Ok () -> "frlg" | Error e -> e
  in
  let start =
    Option.fold ~none:"no start" ~some:Story.Pose.observed_to_string
      (Checkpoint_run.start_of p.checkpoint)
  in
  let missing =
    match missing p with [] -> "none" | l -> String.concat ", " l
  in
  Printf.sprintf "%s; from %s; missing: %s" checked start missing

let case name input expectation = { Case_table.name; input; expectation }

let () =
  Case_table.run "checkpoint_run"
    [
      case "mg-01"
        (summary "mg-01.plan.json")
        "frlg; from CeladonCity (48, 12) south; missing: lift_floor";
      case "mg-02"
        (summary "mg-02.plan.json")
        "frlg; from CeladonCity (39, 21) south; missing: capture";
      case "mg-03"
        (summary "mg-03.plan.json")
        "frlg; from VermilionCity (19, 18) south; missing: none";
    ]
