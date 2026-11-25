module J = Plan_json

type param = { param : string; param_kind : string }
type fragment = { name : string; params : param list; events : J.fields list }
type t = fragment list

let format = "gamepilot-fragments/1"
let ( let* ) = Result.bind
let error where fmt = Printf.ksprintf (fun m -> Error (where ^ m)) fmt

let rec all_ok acc = function
  | [] -> Ok (List.rev acc)
  | r :: rest -> Result.bind r (fun x -> all_ok (x :: acc) rest)

let field where key fields =
  Option.to_result
    ~none:(where ^ key ^ " is missing.")
    (List.assoc_opt key fields)

let as_object where key = function
  | `Assoc f -> Ok f
  | _ -> error where "%s is not an object." key

let as_list where key = function
  | `List l -> Ok l
  | _ -> error where "%s is not an array." key

let as_string where key = function
  | `String s -> Ok s
  | _ -> error where "%s is not a string." key

let placeholder text =
  match String.index_opt text '.' with
  | Some i ->
      ( String.sub text 0 i,
        Some (String.sub text (i + 1) (String.length text - i - 1)) )
  | None -> (text, None)

let rec placeholders_from text i =
  match String.index_from_opt text i '{' with
  | None -> []
  | Some a -> (
      match String.index_from_opt text a '}' with
      | None -> []
      | Some b ->
          placeholder (String.sub text (a + 1) (b - a - 1))
          :: placeholders_from text (b + 1))

let placeholders text = placeholders_from text 0

let rec strings : Yojson.Safe.t -> string list = function
  | `String s -> [ s ]
  | `List l -> List.concat_map strings l
  | `Assoc f -> List.concat_map (fun (_, v) -> strings v) f
  | _ -> []

let check_placeholders where params value =
  let declared = List.map (fun p -> p.param) params in
  let unknown (name, _) = not (List.mem name declared) in
  match
    List.find_opt unknown (List.concat_map placeholders (strings value))
  with
  | Some (name, _) -> error where "{%s} names no parameter." name
  | None -> Ok ()

let event where params i value =
  let where = Printf.sprintf "%sevents[%d]." where i in
  let* fields = as_object where "the event" value in
  let* _ = Result.bind (field where "id" fields) (as_string where "id") in
  let* () = check_placeholders where params value in
  Ok fields

let param where (name, kind) =
  Result.map
    (fun k -> { param = name; param_kind = k })
    (as_string where name kind)

let fragment where (name, value) =
  let* fields = as_object (where ^ "fragments.") name value in
  let where = Printf.sprintf "%sfragments.%s." where name in
  let* params =
    Result.bind (field where "params" fields) (as_object where "params")
  in
  let* params = all_ok [] (List.map (param (where ^ "params.")) params) in
  let* events =
    Result.bind (field where "events" fields) (as_list where "events")
  in
  let* events = all_ok [] (List.mapi (event where params) events) in
  Ok { name; params; events }

let parse ~source json =
  let where = source ^ ": " in
  let* top = as_object where "the table" json in
  let* named =
    Result.bind (field where "format" top) (as_string where "format")
  in
  let* () =
    if named = format then Ok ()
    else error where "format is \"%s\", not %s." named format
  in
  let* fragments =
    Result.bind (field where "fragments" top) (as_object where "fragments")
  in
  all_ok [] (List.map (fragment where) fragments)

let fragments t = t

let find t name =
  match List.find_opt (fun f -> f.name = name) t with
  | Some f -> Ok f
  | None ->
      Error
        (Name_suggestion.unknown ~what:"fragment" name
           (List.map (fun f -> f.name) t))
