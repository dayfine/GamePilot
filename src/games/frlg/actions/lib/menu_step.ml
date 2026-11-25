(* Menu_input.run takes a step that returns nothing: the value comes back
   through [value], set once the step has returned. *)
let result step =
  let value = ref None in
  Result.bind
    (Menu_input.run (fun () -> value := Some (step ())))
    (fun () ->
      Option.to_result !value
        ~none:
          (Checkpoints_run.Failure.cause "no_value" "the step returned no value"))
