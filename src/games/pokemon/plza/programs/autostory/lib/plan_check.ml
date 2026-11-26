module P = Plza_engine

let all check items =
  List.fold_left (fun r x -> Result.bind r (fun () -> check x)) (Ok ()) items

let skip_flags ~id (e : P.Plan.event) =
  Result.map_error
    (fun why -> Printf.sprintf "%s event %s: %s" id e.id why)
    (all Resume_flags.known e.skip_if)

let check (plan : P.Plan.t) =
  let id = plan.checkpoint.checkpoint_id in
  all (skip_flags ~id) plan.checkpoint.events
