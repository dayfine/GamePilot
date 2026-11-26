(* A program's run options: the declaration, the check of what a run gives,
   and the lookups. *)

type value = One_of of string list | Int_range of int * int | Text
type presence = Required | Optional | Default of string

type declared = {
  key : string;
  value : value;
  presence : presence;
  doc : string;
}

type t = (string * string) list

let none = []
let ( let* ) = Result.bind

let pair text =
  match String.index_opt text '=' with
  | None -> Error ("--options " ^ text ^ ": not KEY=VALUE")
  | Some 0 -> Error ("--options " ^ text ^ ": an empty key")
  | Some i ->
      Ok
        ( String.sub text 0 i,
          String.sub text (i + 1) (String.length text - i - 1) )

let value_text = function
  | One_of words -> String.concat " | " words
  | Int_range (low, high) -> Printf.sprintf "%d to %d" low high
  | Text -> "text"

let presence_text = function
  | Required -> " (required)"
  | Optional -> ""
  | Default v -> " (default " ^ v ^ ")"

let describe d =
  Printf.sprintf "%s=%s%s: %s" d.key (value_text d.value)
    (presence_text d.presence) d.doc

(* Whether the value is one the kind takes. *)
let takes value text =
  match value with
  | One_of words -> List.mem text words
  | Int_range (low, high) -> (
      match int_of_string_opt text with
      | Some n -> n >= low && n <= high && string_of_int n = text
      | None -> false)
  | Text -> text <> ""

let key_char = function
  | 'a' .. 'z' | '0' .. '9' | '-' | '_' -> true
  | _ -> false

let check_one_declared seen d =
  let* seen = seen in
  let bad why = Error ("option " ^ d.key ^ ": " ^ why) in
  if d.key = "" || not (String.for_all key_char d.key) then
    bad "a key is lower case, digits, - and _"
  else if List.mem d.key seen then bad "declared twice"
  else
    match (d.value, d.presence) with
    | One_of [], _ -> bad "no value to choose"
    | Int_range (low, high), _ when low > high -> bad "an empty range"
    | value, Default v when not (takes value v) ->
        bad ("the default " ^ v ^ " is not " ^ value_text value)
    | _ -> Ok (d.key :: seen)

let check_declaration decls =
  Result.map ignore (List.fold_left check_one_declared (Ok []) decls)

let taken decls =
  String.concat ", "
    (List.map (fun d -> d.key ^ " (" ^ value_text d.value ^ ")") decls)

let unknown decls key =
  match decls with
  | [] -> Error ("--options " ^ key ^ ": this program takes no options")
  | _ ->
      Error
        ("--options " ^ key ^ ": not an option of this program; it takes "
       ^ taken decls)

(* A given pair: its key declared and given once, its value one it takes. *)
let check_given decls acc (key, v) =
  let* given = acc in
  match List.find_opt (fun d -> d.key = key) decls with
  | _ when List.mem_assoc key given ->
      Error ("--options " ^ key ^ " is given twice")
  | None -> unknown decls key
  | Some d when not (takes d.value v) ->
      Error
        (Printf.sprintf "--options %s=%s: %s is %s" key v key
           (value_text d.value))
  | Some _ -> Ok ((key, v) :: given)

(* The run's value of one declared key, in the declaration's order. *)
let chosen given acc d =
  let* chosen = acc in
  match (List.assoc_opt d.key given, d.presence) with
  | Some v, _ | None, Default v -> Ok ((d.key, v) :: chosen)
  | None, Optional -> Ok chosen
  | None, Required ->
      Error
        (Printf.sprintf "--options %s=%s is required" d.key (value_text d.value))

let check decls pairs =
  let* given = List.fold_left (check_given decls) (Ok []) pairs in
  Result.map List.rev (List.fold_left (chosen given) (Ok []) decls)

let pairs t = t
let find t key = List.assoc_opt key t
let int t key = Option.bind (find t key) int_of_string_opt
let to_text t = String.concat " " (List.map (fun (k, v) -> k ^ "=" ^ v) t)
