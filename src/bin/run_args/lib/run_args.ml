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

let positional ~is_plan_folder = function
  | a :: flags when not (is_flag a) ->
      let target = if is_plan_folder a then Plan_folder a else Program a in
      Ok { target; flags }
  | _ -> Error "a program id, a plan folder or --plan FILE is required"

let parse ~is_plan_folder args =
  match (take "--plan" args, take "--program" args) with
  | Error e, _ | _, Error e -> Error e
  | Ok (Some _), Ok (Some _) -> Error "--plan and --program: give one"
  | Ok (Some (plan, flags)), Ok None -> Ok { target = Plan plan; flags }
  | Ok None, Ok (Some (id, flags)) -> Ok { target = Program id; flags }
  | Ok None, Ok None -> positional ~is_plan_folder args

let of_old_command command args =
  match (command, args) with
  | "checkpoints", _ -> Some (parse ~is_plan_folder:(fun _ -> true) args)
  | "checkpoint", plan :: flags -> Some (Ok { target = Plan plan; flags })
  | "checkpoint", [] -> Some (Error "a plan file is required")
  | _ -> None

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
    | Plan_folder dir -> [ dir ]
    | Plan file -> [ "--plan"; file ]
  in
  String.concat " " ("gamepilot" :: "run" :: List.map quote (target @ t.flags))

let old_command_notice command t =
  Printf.sprintf "gamepilot %s is now gamepilot run: %s" command
    (command_line t)
