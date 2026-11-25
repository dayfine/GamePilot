type fields = (string * Yojson.Safe.t) list

let ( let* ) = Result.bind
let fields_of = function `Assoc f -> f | _ -> []

let object_field key fields =
  match List.assoc_opt key fields with Some (`Assoc f) -> f | _ -> []

let string_field key fields =
  match List.assoc_opt key fields with Some (`String s) -> Some s | _ -> None

let set key value fields =
  if List.mem_assoc key fields then
    List.map (fun (k, v) -> if k = key then (k, value) else (k, v)) fields
  else fields @ [ (key, value) ]

let without key fields = List.filter (fun (k, _) -> k <> key) fields

(* The [i]th event rewritten, its error naming it. *)
let rewrite_nth ~where ~step state i event =
  Result.map_error
    (Printf.sprintf "%sevents[%d]: %s" where i)
    (step state (fields_of event))

let rec rewrite_from ~where ~step state i acc = function
  | [] -> Ok (List.rev acc)
  | event :: rest ->
      let* rewritten, state = rewrite_nth ~where ~step state i event in
      rewrite_from ~where ~step state (i + 1)
        (List.rev_append rewritten acc)
        rest

let rewrite_events ~source ~start ~step json =
  let plan = fields_of json in
  let checkpoint = object_field "checkpoint" plan in
  match List.assoc_opt "events" checkpoint with
  | Some (`List events) ->
      let where = source ^ ": checkpoint." in
      let* events = rewrite_from ~where ~step (start checkpoint) 0 [] events in
      let checkpoint = set "events" (`List events) checkpoint in
      Ok (`Assoc (set "checkpoint" (`Assoc checkpoint) plan))
  | _ -> Ok json
