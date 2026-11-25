type json = Yojson.Safe.t

exception Decode_error of string

let fail fmt = Printf.ksprintf (fun s -> raise (Decode_error s)) fmt

let fields what = function
  | `Assoc kv -> kv
  | _ -> fail "%s: expected an object" what

let field what name j =
  match List.assoc_opt name (fields what j) with
  | Some v -> v
  | None -> fail "%s: missing field %S" what name

let field_opt what name j = List.assoc_opt name (fields what j)

let to_int what = function
  | `Int i -> i
  | `Float f when Float.is_integer f -> int_of_float f
  | _ -> fail "%s: expected an integer" what

let to_float what = function
  | `Int i -> float_of_int i
  | `Float f -> f
  | _ -> fail "%s: expected a number" what

let to_string what = function
  | `String s -> s
  | _ -> fail "%s: expected a string" what

let to_list what = function
  | `List l -> l
  | _ -> fail "%s: expected a list" what

let int_field what name j = to_int (what ^ "." ^ name) (field what name j)
let float_field what name j = to_float (what ^ "." ^ name) (field what name j)
let string_field what name j = to_string (what ^ "." ^ name) (field what name j)
let list_field what name j = to_list (what ^ "." ^ name) (field what name j)

let string_list_field what name j =
  List.map (to_string (what ^ "." ^ name)) (list_field what name j)

let json_of_strings l = `List (List.map (fun s -> `String s) l)

let parse_json s =
  try Yojson.Safe.from_string s
  with Yojson.Json_error e -> fail "bad JSON: %s" e

let member_opt name = function
  | `Assoc fields -> List.assoc_opt name fields
  | _ -> None

let number_opt = function
  | `Int i -> Some (float_of_int i)
  | `Float f -> Some f
  | _ -> None

let rec all_opt f = function
  | [] -> Some []
  | x :: rest -> (
      match f x with
      | None -> None
      | Some y -> Option.map (List.cons y) (all_opt f rest))

let numbers_opt = function `List items -> all_opt number_opt items | _ -> None
