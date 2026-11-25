let ( let* ) = Result.bind

type fields = (string * Yojson.Safe.t) list

let fields_of = function `Assoc f -> f | _ -> []

let str key fields =
  match List.assoc_opt key fields with Some (`String s) -> Some s | _ -> None

let set key value fields =
  if List.mem_assoc key fields then
    List.map (fun (k, v) -> if k = key then (k, value) else (k, v)) fields
  else fields @ [ (key, value) ]

let call_fields = [ "id"; "fragment"; "args"; "why"; "skip_if" ]

let check_fields (call : fields) =
  match List.find_opt (fun (k, _) -> not (List.mem k call_fields)) call with
  | Some (k, _) -> Error (k ^ " is not a field a fragment call takes.")
  | None -> Ok ()

let arg (name, value) =
  match value with
  | `String s -> Ok (name, s)
  | _ -> Error ("args." ^ name ^ " is not a string.")

let rec all_ok acc = function
  | [] -> Ok (List.rev acc)
  | r :: rest -> Result.bind r (fun x -> all_ok (x :: acc) rest)

let named = function [] -> "none" | l -> String.concat ", " l

let object_field key fields =
  fields_of (Option.value ~default:`Null (List.assoc_opt key fields))

let args (f : Fragment_table.fragment) (call : fields) =
  let* given = all_ok [] (List.map arg (object_field "args" call)) in
  let names = List.sort compare (List.map fst given) in
  if names = List.sort compare f.params then Ok given
  else
    Error
      (Printf.sprintf "%s takes args %s, not %s." f.name (named f.params)
         (named names))

let event_id call_id suffix =
  if suffix = "" then call_id else call_id ^ "." ^ suffix

(* One of the fragment's events, filled in for the call. *)
let instance ~call_id ~call given template =
  let filled = fields_of (Fragment_table.substitute given (`Assoc template)) in
  let id = event_id call_id (Option.value ~default:"" (str "id" filled)) in
  let why =
    match (str "why" filled, List.assoc_opt "why" call) with
    | Some _, _ | None, None -> []
    | None, Some why -> [ ("why", why) ]
  in
  let skip = List.filter (fun (k, _) -> k = "skip_if") call in
  `Assoc (set "id" (`String id) filled @ skip @ why)

let expand_call table call name =
  let* () = check_fields call in
  let* fragment = Fragment_table.find table name in
  let* given = args fragment call in
  let call_id = Option.value ~default:"" (str "id" call) in
  Ok (List.map (instance ~call_id ~call given) fragment.events)

let expand_event table (event : fields) =
  match List.assoc_opt "fragment" event with
  | None -> Ok [ `Assoc event ]
  | Some (`String name) -> expand_call table event name
  | Some _ -> Error "fragment is not a string."

(* The event expanded, its error naming it as the [i]th. *)
let expand_nth table ~where i event =
  Result.map_error
    (Printf.sprintf "%sevents[%d]: %s" where i)
    (expand_event table (fields_of event))

let rec expand_events table ~where i acc = function
  | [] -> Ok (List.rev acc)
  | event :: rest ->
      let* expanded = expand_nth table ~where i event in
      expand_events table ~where (i + 1) (List.rev_append expanded acc) rest

let expand table ~source json =
  let plan = fields_of json in
  let checkpoint = object_field "checkpoint" plan in
  match List.assoc_opt "events" checkpoint with
  | Some (`List events) ->
      let where = source ^ ": checkpoint." in
      let* events = expand_events table ~where 0 [] events in
      let checkpoint = set "events" (`List events) checkpoint in
      Ok (`Assoc (set "checkpoint" (`Assoc checkpoint) plan))
  | _ -> Ok json
