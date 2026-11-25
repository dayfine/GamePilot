let of_names steps =
  (module struct
    type t = Engine_rules.Command_step.t

    let names = steps

    let read name ~where args =
      Json_field.catch (fun () ->
          Plan_fields.known_fields_only ~where [] args;
          name)

    let of_plan name = if List.mem name steps then Some (read name) else None
  end : Action_parts.ACTION_DECODE
    with type t = Engine_rules.Command_step.t)
