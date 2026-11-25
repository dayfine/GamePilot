type fragment = {
  name : string;
  params : string list;
  events : (string * Yojson.Safe.t) list list;
}

type t = fragment list

let format = "gamepilot-fragments/1"
let asset = "src/games/frlg/fragments/fragments.json"
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

let replace_all ~sub ~by text =
  let n = String.length sub in
  let b = Buffer.create (String.length text) in
  let rec go i =
    if i > String.length text - n then
      Buffer.add_string b (String.sub text i (String.length text - i))
    else if String.sub text i n = sub then (
      Buffer.add_string b by;
      go (i + n))
    else (
      Buffer.add_char b text.[i];
      go (i + 1))
  in
  if n = 0 then text
  else (
    go 0;
    Buffer.contents b)

let rec substitute args : Yojson.Safe.t -> Yojson.Safe.t = function
  | `String s ->
      `String
        (List.fold_left
           (fun s (k, v) -> replace_all ~sub:("{" ^ k ^ "}") ~by:v s)
           s args)
  | `List l -> `List (List.map (substitute args) l)
  | `Assoc f -> `Assoc (List.map (fun (k, v) -> (k, substitute args v)) f)
  | other -> other

(* Every string of the event with its params filled holds no "{" left. *)
let rec unfilled : Yojson.Safe.t -> string option = function
  | `String s when String.contains s '{' -> Some s
  | `List l -> List.find_map unfilled l
  | `Assoc f -> List.find_map (fun (_, v) -> unfilled v) f
  | _ -> None

let event where params i value =
  let where = Printf.sprintf "%sevents[%d]." where i in
  let* fields = as_object where "" value in
  let* id = field where "id" fields in
  let* _ = as_string where "id" id in
  let filled = substitute (List.map (fun p -> (p, "")) params) value in
  match unfilled filled with
  | Some s -> error where "\"%s\" names a parameter that is not in params." s
  | None -> Ok fields

let fragment where (name, value) =
  let* fields = as_object (where ^ "fragments.") name value in
  let where = Printf.sprintf "%sfragments.%s." where name in
  let* params =
    Result.bind (field where "params" fields) (as_list where "params")
  in
  let* params = all_ok [] (List.map (as_string where "params") params) in
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

let read () =
  match Frlg_repo_files.Repo_files.locate asset with
  | None -> Error (asset ^ " not found from the working directory")
  | Some path ->
      Result.bind
        (Frlg_repo_files.Json_file.read path)
        (parse ~source:"fragments.json")

let loaded = lazy (read ())
let load () = Lazy.force loaded
let fragments t = t

let find t name =
  match List.find_opt (fun f -> f.name = name) t with
  | Some f -> Ok f
  | None ->
      Error
        (Frlg_places.Name_suggestion.unknown ~what:"fragment" name
           (List.map (fun f -> f.name) t))
