exception Invalid of string

type obj = (string * Yojson.Safe.t) list

let fail format =
  Printf.ksprintf (fun message -> raise (Invalid message)) format

let item_where where key i = Printf.sprintf "%s%s[%d]." where key i

let as_object where : Yojson.Safe.t -> obj = function
  | `Assoc fields -> fields
  | _ -> fail "%s is not a JSON object." where

let find key (obj : obj) = List.assoc_opt key obj
let has key obj = Option.is_some (find key obj)

let field ~where key obj =
  match find key obj with
  | Some value -> value
  | None -> fail "%s%s is missing." where key

let int ~where key obj =
  match field ~where key obj with
  | `Int n -> n
  | _ -> fail "%s%s is not an integer." where key

let string ~where key obj =
  match field ~where key obj with
  | `String text -> text
  | _ -> fail "%s%s is not a string." where key

let string_opt ~where key obj =
  if has key obj then Some (string ~where key obj) else None

let bool_or ~where ~default key obj =
  match find key obj with
  | None -> default
  | Some (`Bool b) -> b
  | Some _ -> fail "%s%s is not true or false." where key

let list_opt ~where key obj =
  match find key obj with
  | None -> None
  | Some (`List items) -> Some items
  | Some _ -> fail "%s%s is not an array." where key

let object_opt ~where key obj =
  Option.map (as_object (where ^ key)) (find key obj)

let entries ~where key obj =
  Option.value ~default:[] (object_opt ~where key obj)

let records ~where key obj read =
  let read_item i value =
    let item = item_where where key i in
    let item_path = String.sub item 0 (String.length item - 1) in
    read ~where:item (as_object item_path value)
  in
  List.mapi read_item (Option.value ~default:[] (list_opt ~where key obj))

let strings where : Yojson.Safe.t -> string list = function
  | `List items ->
      List.mapi
        (fun i -> function
          | `String text -> text | _ -> fail "%s[%d] is not a string." where i)
        items
  | _ -> fail "%s is not a list of strings." where
