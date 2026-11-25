module Own_kind = Own_kind
module Postcondition_check = Postcondition_check

module Pose = struct
  include Pose

  type t = declared

  let decode ~where obj =
    Json_field.catch (fun () -> Pose_decode.declared ~where obj)

  (* A zone is decoded and never checked: it holds wherever the player is. *)
  let matches (pose : t) observed =
    match pose with Grid grid -> grid_matches grid observed | Zone _ -> true

  let text = declared_to_string
  let observed_text = observed_to_string
end

module Kind = struct
  type t = Own_kind.t

  let decode name =
    Option.map
      (fun read ~where args -> Json_field.catch (fun () -> read ~where args))
      (Own_kind.decoder name)

  let text = Own_kind.text
end

module Postconditions = struct
  include Postconditions

  type reads = Postcondition_check.observed

  let decode ~where obj =
    Json_field.catch (fun () -> Postcondition_decode.postconditions ~where obj)

  let check = Postcondition_check.check
end

module Saved = struct
  type t = { start : Postcondition_check.start; at : Pose.observed option }

  let ( let* ) = Result.bind

  let to_json { start; at } =
    `Assoc
      (Postcondition_check.start_to_json start
      @ [ ("at", Option.fold ~none:`Null ~some:Pose.observed_to_json at) ])

  let at_of_json = function
    | `Null -> Ok None
    | json ->
        Result.map_error (fun e -> "at: " ^ e) (Pose.observed_of_json json)
        |> Result.map Option.some

  let of_json = function
    | `Assoc fields ->
        let* start = Postcondition_check.start_of_json fields in
        let* at =
          at_of_json (Option.value (List.assoc_opt "at" fields) ~default:`Null)
        in
        Ok { start; at }
    | _ -> Error "what is kept is not an object"
end
