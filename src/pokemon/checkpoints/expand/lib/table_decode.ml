let error where fmt = Printf.ksprintf (fun m -> Error (where ^ m)) fmt

let all_ok results =
  let rec go acc = function
    | [] -> Ok (List.rev acc)
    | r :: rest -> Result.bind r (fun x -> go (x :: acc) rest)
  in
  go [] results

let field where key fields =
  match List.assoc_opt key fields with
  | Some v -> Ok v
  | None -> error where "%s is missing." key

let as_object where key = function
  | `Assoc fields -> Ok fields
  | _ -> error where "%s is not an object." key

let as_list where key = function
  | `List items -> Ok items
  | _ -> error where "%s is not an array." key

let as_string where key = function
  | `String s -> Ok s
  | _ -> error where "%s is not a string." key

let string where key fields =
  Result.bind (field where key fields) (as_string where key)

let only where allowed fields =
  match List.find_opt (fun (k, _) -> not (List.mem k allowed)) fields with
  | Some (k, _) -> error where "%s is not a known field." k
  | None -> Ok ()
