module F = Json_field

module type POSE_DECODE = sig
  type t

  val pose_of_plan : where:string -> Json_field.obj -> (t, string) result
end

module type PROMISES_DECODE = sig
  type t

  val keys : string list
  val promises_of_plan : where:string -> Json_field.obj -> (t, string) result
end

let ( let* ) = Result.bind

module Make (P : POSE_DECODE) (R : PROMISES_DECODE) = struct
  let position ~where obj =
    match F.find "position" obj with
    | None -> Ok None
    | Some value ->
        let path = where ^ "position" in
        let* fields = F.catch (fun () -> F.as_object path value) in
        Result.map Option.some (P.pose_of_plan ~where:(path ^ ".") fields)

  let postconditions_of_plan ~where obj =
    let* () =
      F.catch (fun () ->
          Plan_fields.known_fields_only ~where ("position" :: R.keys) obj)
    in
    let* position = position ~where obj in
    let* promises = R.promises_of_plan ~where obj in
    Ok { Engine_rules.Promises.position; promises }
end
