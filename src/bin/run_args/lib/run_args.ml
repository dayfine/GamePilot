(* gamepilot run's args, and the old checkpoints and checkpoint commands it
   replaces (Run_args.mli). *)

type target = Program of string | Plan_folder of string | Plan of string
type t = { target : target; flags : string list }

(* The value of [flag] wherever it is in [args], and the other args. *)
let take flag args =
  let rec go kept = function
    | [] -> Ok None
    | [ a ] when a = flag -> Error (flag ^ " needs a value")
    | a :: v :: rest when a = flag -> Ok (Some (v, List.rev_append kept rest))
    | a :: rest -> go (a :: kept) rest
  in
  go [] args

let is_flag a = String.length a > 0 && a.[0] = '-'

(* A plan folder given bare: a path, never a name alone, which is a program
   id's. *)
let is_path a = String.exists (fun c -> c = '/' || c = '\\') a

let named_targets =
  [
    ("--plan", fun file -> Plan file);
    ("--program", fun id -> Program id);
    ("--plan-dir", fun dir -> Plan_folder dir);
  ]

(* The targets the flags name, and the args left. *)
let rec named found args = function
  | [] -> Ok (found, args)
  | (flag, target) :: rest -> (
      match take flag args with
      | Error e -> Error e
      | Ok None -> named found args rest
      | Ok (Some (v, args)) -> named (target v :: found) args rest)

let positional ~bare = function
  | a :: flags when not (is_flag a) -> Ok { target = bare a; flags }
  | _ ->
      Error
        "a program id, a plan folder (a path, or --plan-dir DIR) or --plan \
         FILE is required"

let parse_with ~bare args =
  match named [] args named_targets with
  | Error e -> Error e
  | Ok ([], _) -> positional ~bare args
  | Ok ([ target ], flags) -> Ok { target; flags }
  | Ok (_, _) -> Error "--plan, --program and --plan-dir: give one"

let parse =
  parse_with ~bare:(fun a -> if is_path a then Plan_folder a else Program a)

type old_command = Not_old_command | Invalid_old_args of string | Run of t

let of_result = function Ok t -> Run t | Error e -> Invalid_old_args e

let of_old_command command args =
  match (command, args) with
  | "checkpoints", _ ->
      of_result (parse_with ~bare:(fun a -> Plan_folder a) args)
  | "checkpoint", plan :: flags -> Run { target = Plan plan; flags }
  | "checkpoint", [] -> Invalid_old_args "a plan file is required"
  | _ -> Not_old_command

let plain c =
  match c with
  | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' -> true
  | '-' | '_' | '.' | '/' | ',' | ':' | '=' | '+' | '@' -> true
  | _ -> false

(* Single quotes, as sh reads them, whatever the platform. *)
let quote a =
  if a <> "" && String.for_all plain a then a
  else "'" ^ String.concat {|'\''|} (String.split_on_char '\'' a) ^ "'"

let command_line t =
  let target =
    match t.target with
    | Program id -> [ id ]
    | Plan_folder dir when is_path dir -> [ dir ]
    | Plan_folder dir -> [ "--plan-dir"; dir ]
    | Plan file -> [ "--plan"; file ]
  in
  String.concat " " ("gamepilot" :: "run" :: List.map quote (target @ t.flags))

let old_command_notice command t =
  Printf.sprintf "gamepilot %s is now gamepilot run: %s" command
    (command_line t)
