module Plan = Plza_engine.Plan
module Starter = Plza_story.Starter

let of_run_options options =
  match Run_options.find options "starter" with
  | None -> Ok None
  | Some tag -> (
      match Starter.of_tag tag with
      | Some s -> Ok (Some s)
      | None -> Error "--options starter: not grass, fire or water")

let to_starter (event : Plan.event) =
  match event.kind with
  | Game (Walk args) -> args.to_starter
  | Talk | Answer _ | Scene | Save | Named_action _ -> false

let refused =
  "--options starter is the starter 01.04-starter-and-andi walks to, and this \
   series does not walk there (the save has its starter already): start it at \
   or before 01.04-starter-and-andi, or drop it"

let series_check starter checkpoints =
  let walks_to_starter =
    List.exists
      (fun (cp : Plan.checkpoint) -> List.exists to_starter cp.events)
      checkpoints
  in
  match starter with
  | Some _ when not walks_to_starter -> Error refused
  | Some _ | None -> Ok ()
