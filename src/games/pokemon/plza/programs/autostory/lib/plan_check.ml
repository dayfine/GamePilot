module P = Plza_checkpoints

let ( let* ) = Result.bind

let execution_key ~id = function
  | ("start_signature" | "end_signature"), _ -> Ok ()
  | "reload_when_chained", `Bool _ -> Ok ()
  | "reload_when_chained", _ ->
      Error (id ^ ": execution.reload_when_chained is not a boolean")
  | key, _ -> Error (Printf.sprintf "%s: unknown execution key %S" id key)

let all check items =
  List.fold_left (fun r x -> Result.bind r (fun () -> check x)) (Ok ()) items

let skip_flags ~id (e : P.Plan.event) =
  Result.map_error
    (fun why -> Printf.sprintf "%s event %s: %s" id e.id why)
    (all Resume_flags.known e.skip_if)

let check (plan : P.Plan.t) =
  let id = plan.checkpoint.checkpoint_id in
  let* () = all (execution_key ~id) plan.execution in
  let* () =
    Result.map_error Engine_run.Failure.cause_to_string
      (Start_signature.decode ~checkpoint_id:id plan.execution)
  in
  all (skip_flags ~id) plan.checkpoint.events
