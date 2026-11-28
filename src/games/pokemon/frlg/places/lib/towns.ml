type town = {
  key : string;
  nurse : string;
  fly : string;
  mart : string option;
  pc : string option;
  outside : string option;
}

type t = town list

let ( let* ) = Result.bind

module D = Engine_expand.Table_decode

let error = D.error
let string = D.string

let a_place where ~places key name =
  if List.mem name places then Ok name
  else error where "%s %s is not a place of the table." key name

let place_field where ~places key fields =
  Result.bind (string where key fields) (a_place where ~places key)

let optional_place where ~places key fields =
  if List.mem_assoc key fields then
    Result.map Option.some (place_field where ~places key fields)
  else Ok None

let town_of where ~places key fields =
  let* nurse = place_field where ~places "nurse" fields in
  let* fly = string where "fly" fields in
  let* mart = optional_place where ~places "mart" fields in
  let* pc = optional_place where ~places "pc" fields in
  let* outside = optional_place where ~places "outside" fields in
  Ok { key; nurse; fly; mart; pc; outside }

let town where ~places (key, value) =
  let where = Printf.sprintf "%stowns.%s." where key in
  match value with
  | `Assoc fields -> town_of where ~places key fields
  | _ -> error where "is not an object."

let parse ~where ~places = function
  | `Assoc towns -> D.all_ok (List.map (town where ~places) towns)
  | _ -> error where "towns is not an object."

let empty = []
let towns t = t

let find t key =
  match List.find_opt (fun town -> town.key = key) t with
  | Some town -> Ok town
  | None ->
      Error
        (Name_suggestion.unknown ~what:"town" key (List.map (fun t -> t.key) t))

let find_by_fly t fly = List.find_opt (fun town -> town.fly = fly) t

let field t key ~field =
  let* town = find t key in
  match field with
  | None -> Ok town.key
  | Some "nurse" -> Ok town.nurse
  | Some "fly" -> Ok town.fly
  | Some "mart" -> Option.to_result ~none:(key ^ " has no mart place") town.mart
  | Some "pc" -> Option.to_result ~none:(key ^ " has no pc place") town.pc
  | Some "outside" ->
      Option.to_result ~none:(key ^ " has no outside place") town.outside
  | Some other ->
      Error
        (Printf.sprintf "a town has no %s (nurse, fly, mart, pc, outside)" other)
