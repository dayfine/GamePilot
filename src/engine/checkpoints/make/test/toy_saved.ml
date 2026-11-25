type t = { start : int option; at : Toy_terms.Pose.t option }

let ( let* ) = Result.bind

let pose_to_yojson (p : Toy_terms.Pose.t) =
  `Assoc
    [
      ("place", `String p.place);
      ("spot", Option.fold ~none:`Null ~some:(fun s -> `String s) p.spot);
    ]

let pose_of_yojson : Yojson.Safe.t -> (Toy_terms.Pose.t, string) result =
  function
  | `Assoc [ ("place", `String place); ("spot", `String spot) ] ->
      Ok { place; spot = Some spot }
  | `Assoc [ ("place", `String place); ("spot", `Null) ] ->
      Ok { place; spot = None }
  | _ -> Error "not a place"

let to_yojson { start; at } =
  `Assoc
    [
      ("start_gold", Option.fold ~none:`Null ~some:(fun n -> `Int n) start);
      ("at", Option.fold ~none:`Null ~some:pose_to_yojson at);
    ]

let start_of_yojson fields =
  match List.assoc_opt "start_gold" fields with
  | Some (`Int n) -> Ok (Some n)
  | Some `Null | None -> Ok None
  | Some _ -> Error "start_gold is not a number"

let at_of_yojson = function
  | `Null -> Ok None
  | json ->
      Result.map_error (fun e -> "at: " ^ e) (pose_of_yojson json)
      |> Result.map Option.some

let of_yojson = function
  | `Assoc fields ->
      let* start = start_of_yojson fields in
      let* at =
        at_of_yojson (Option.value (List.assoc_opt "at" fields) ~default:`Null)
      in
      Ok { start; at }
  | _ -> Error "what is kept is not an object"
