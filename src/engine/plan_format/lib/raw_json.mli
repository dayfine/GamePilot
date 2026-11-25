(** What a plan keeps as written ({!Engine_plan.Plan.RAW}): a game action's
    args, the [execution] and the [metadata], as the plan file's JSON objects.
*)

type t = Json_field.obj
